import AppKit
import KoechoCore
import KoechoPlatform
import os

@MainActor
final class VoiceInputCoordinator: VoiceInputDelegate {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "VoiceInputCoordinator")
  private let appState: AppState
  private let makeEngine: () -> any VoiceInputEngine
  private let panel: InputPanel

  var textView: (any TextViewOperating)?

  private(set) var engine: any VoiceInputEngine
  private(set) var voiceInsertionPoint: Int = 0
  var currentVoiceTarget: VoiceTarget = .textEditor

  var replayState: ReplayState = .idle
  private var accumulatedFinalizedText: String = ""
  private static let replaySuppressionDuration: TimeInterval = 2.0
  private var transcriberAlreadyRestarted = false
  private(set) var isStoppingEngine = false

  var onAutoReplacement: (() -> Void)?
  var onCursorAutoReplacement: (() -> Void)?

  enum VoiceTarget {
    case textEditor
    case prompt
  }

  /// Replay suppression lifecycle for SpeechAnalyzer transcriber restarts.
  /// Locally finalized text would otherwise be re-delivered (replayed) by the
  /// restarted transcriber; this state machine tracks what to suppress.
  /// See decisions/0021.
  enum ReplayState: Equatable {
    /// No local finalization pending; volatile and finalized text flow normally.
    case idle
    /// Text was finalized locally and the transcriber restart has not
    /// completed yet. All volatile updates are suppressed.
    case restartInProgress(localText: String)
    /// A restart completed; replayed text matching `localText` is suppressed
    /// until `deadline`. A re-finalization during the window swaps `localText`
    /// but keeps the deadline (see `recordLocalFinalization`).
    case suppressing(localText: String, deadline: Date)

    /// Transition for a local finalization (cursor move / Enter over volatile
    /// text). An existing suppression window keeps its deadline.
    mutating func recordLocalFinalization(_ text: String) {
      switch self {
      case .idle, .restartInProgress:
        self = .restartInProgress(localText: text)
      case .suppressing(_, let deadline):
        self = .suppressing(localText: text, deadline: deadline)
      }
    }

    /// Transition for a completed transcriber restart. No-op when idle:
    /// a suppression window only makes sense for a recorded finalization.
    mutating func beginSuppression(deadline: Date) {
      switch self {
      case .idle:
        break
      case .restartInProgress(let localText), .suppressing(let localText, _):
        self = .suppressing(localText: localText, deadline: deadline)
      }
    }
  }

  init(
    appState: AppState,
    makeEngine: @escaping () -> any VoiceInputEngine,
    panel: InputPanel
  ) {
    self.appState = appState
    self.makeEngine = makeEngine
    self.panel = panel
    self.engine = makeEngine()
    self.engine.delegate = self
  }

  // MARK: - Engine lifecycle

  func startEngine() {
    engine.start()
  }

  func stopEngine() async {
    isStoppingEngine = true
    await engine.stop()
    isStoppingEngine = false
  }

  func cancelEngine() {
    engine.cancel()
  }

  func switchEngine() async {
    await engine.stop()
    textView?.clearVolatileText()
    if let textView {
      appState.inputText = textView.finalizedString
    }
    regenerateEngine()
    voiceInsertionPoint =
      textView?.selectedRange().location ?? (appState.inputText as NSString).length
    clearReplayState()
    accumulatedFinalizedText = ""
    engine.start()
    logger.info("Engine switched while panel visible")
  }

  func prepareForShow() {
    regenerateEngine()
    resetShowState()
  }

  func prepareForShowWithoutEngine() {
    resetShowState()
  }

  private func resetShowState() {
    moveVoiceInsertionPoint(toEndOf: appState.inputText)
    currentVoiceTarget = .textEditor
    clearReplayState()
    accumulatedFinalizedText = ""
  }

  // MARK: - Voice insertion point

  /// Move the voice insertion point, keeping it within the bounds of `text`.
  func moveVoiceInsertionPoint(to point: Int, in text: String) {
    voiceInsertionPoint = max(0, min(point, (text as NSString).length))
  }

  /// Move the voice insertion point to the end of `text`.
  func moveVoiceInsertionPoint(toEndOf text: String) {
    moveVoiceInsertionPoint(to: (text as NSString).length, in: text)
  }

  func finalizeRemainingVolatile() {
    if textView?.volatileRange != nil {
      textView?.finalizeVolatileText()
    }
  }

  func resetState() {
    clearReplayState()
    accumulatedFinalizedText = ""
  }

  func configureEngineWithTextView() {
    if let dictation = engine as? DictationEngine,
      let tv = textView as? VoiceInputTextView
    {
      dictation.configure(panel: panel, textView: tv)
    }
  }

  // MARK: - Text editing hooks

  func handleCursorMoved(_ position: Int) {
    guard !(engine is DictationEngine) else { return }
    if let textView, textView.volatileRange != nil {
      if let range = textView.volatileRange,
        range.location + range.length <= (textView.string as NSString).length
      {
        let volatileText = (textView.string as NSString).substring(with: range)
        textView.finalizeVolatileText()
        recordLocalFinalization(volatileText)
      } else {
        textView.clearVolatileText()
      }
      appState.inputText = textView.finalizedString
      onCursorAutoReplacement?()
      restartTranscriberIfNeeded()
    }
    voiceInsertionPoint = position
  }

  func handleTextChanged() {
    restartTranscriberIfNeeded()
  }

  /// Record that volatile text was finalized locally (cursor move or typing
  /// over volatile text). The restarted transcriber replays this text, so it
  /// must be tracked for suppression.
  func recordLocalFinalization(_ text: String) {
    replayState.recordLocalFinalization(text)
  }

  func restartDictationIfNeeded() {
    if let dictation = engine as? DictationEngine {
      dictation.restart()
    }
  }

  // MARK: - VoiceInputDelegate

  func voiceInput(didFinalize text: String) {
    guard appState.isInputPanelVisible else { return }

    switch currentVoiceTarget {
    case .prompt:
      transcriberAlreadyRestarted = false
      appState.promptText += text
      return
    case .textEditor:
      break
    }

    textView?.clearVolatileText()

    switch replayState {
    case .idle:
      break
    case .restartInProgress(let localText):
      clearReplayState()
      accumulatedFinalizedText += localText
    case .suppressing(let localText, _):
      clearReplayState()
      accumulatedFinalizedText += localText
      if text == localText { return }
    }
    transcriberAlreadyRestarted = false

    let newText = stripOverlappingPrefix(text, accumulated: accumulatedFinalizedText)
    guard !newText.isEmpty else { return }

    let inserted = insertFinalizedText(newText, at: voiceInsertionPoint)
    accumulatedFinalizedText += inserted

    if !isStoppingEngine, appState.settings.replacement.isAutoReplacementEnabled {
      onAutoReplacement?()
    }
  }

  func voiceInput(didUpdateVolatile text: String) {
    guard appState.isInputPanelVisible else { return }

    switch replayState {
    case .idle:
      break
    case .restartInProgress:
      // Restart is async (handleCursorMoved / onVolatileFinalized path);
      // suppress all volatile until it completes.
      return
    case .suppressing(let localText, let deadline):
      if Date.now < deadline,
        currentVoiceTarget == .textEditor,
        localText.hasPrefix(text) || text.hasPrefix(localText)
      {
        return
      }
      clearReplayState()
    }

    switch currentVoiceTarget {
    case .prompt:
      return
    case .textEditor:
      transcriberAlreadyRestarted = false
      let point = min(voiceInsertionPoint, textView?.textStorage?.length ?? 0)
      let adjustedText = stripLeadingDuplicatePunctuation(text, at: point)
      textView?.setVolatileText(adjustedText, at: voiceInsertionPoint)
    }
  }

  func voiceInput(didEncounterError error: VoiceInputEngineError) {
    appState.errorMessage = displayMessage(for: error)
  }

  func voiceInput(didUpdateStatus status: VoiceInputEngineStatus?) {
    appState.voiceEngineStatus = status.map { displayMessage(for: $0) }
  }

  // MARK: - Display message conversion

  private func displayMessage(for error: VoiceInputEngineError) -> String {
    switch error {
    case .microphoneAccessDenied:
      String(
        localized:
          "Microphone access denied. Open System Settings > Privacy & Security > Microphone.")
    case .modelDownloadFailed(let description):
      String(localized: "Failed to download speech model: \(description)")
    case .noAudioInputDevice:
      String(localized: "No audio input device available.")
    case .noCompatibleAudioFormat:
      String(localized: "No compatible audio format available.")
    case .audioFormatConversionNotSupported:
      String(localized: "Audio format conversion not supported.")
    case .audioEngineStartFailed(let description):
      String(localized: "Failed to start audio engine: \(description)")
    case .recognitionError(let description):
      String(localized: "Speech recognition error: \(description)")
    }
  }

  private func displayMessage(for status: VoiceInputEngineStatus) -> String {
    switch status {
    case .requestingMicrophoneAccess:
      String(localized: "Requesting microphone access...")
    case .downloadingModel:
      String(localized: "Downloading speech model...")
    }
  }

  // MARK: - Private helpers

  private func regenerateEngine() {
    engine = makeEngine()
    engine.delegate = self
    configureEngineWithTextView()
  }

  private func clearReplayState() {
    replayState = .idle
    transcriberAlreadyRestarted = false
  }

  private func restartTranscriberIfNeeded() {
    if #available(macOS 26, *) {
      guard !transcriberAlreadyRestarted,
        let saEngine = engine as? SpeechAnalyzerEngine
      else { return }
      let shouldSuppressReplay = replayState != .idle
      // Set synchronously to prevent duplicate Task creation from handleCursorMoved + handleTextChanged
      transcriberAlreadyRestarted = true
      Task { @MainActor in
        let didRestart = await saEngine.restartTranscriber()
        if didRestart {
          if shouldSuppressReplay {
            self.replayState.beginSuppression(
              deadline: Date.now + Self.replaySuppressionDuration)
          }
        } else {
          // Restart failed (e.g. not listening): reset flag so next attempt can retry.
          // Don't clearReplayState() here — a concurrent restart may be in flight.
          // replayState will be cleared by didFinalize or clearReplayState elsewhere.
          self.transcriberAlreadyRestarted = false
        }
      }
    }
  }

  private func stripOverlappingPrefix(_ newText: String, accumulated: String) -> String {
    guard !accumulated.isEmpty, !newText.isEmpty else { return newText }
    let accNS = accumulated as NSString
    let newNS = newText as NSString
    let maxSuffixLen = min(min(accNS.length, newNS.length), 512)
    for suffixLen in stride(from: maxSuffixLen, through: 1, by: -1) {
      let suffix = accNS.substring(from: accNS.length - suffixLen)
      let prefix = newNS.substring(to: suffixLen)
      if suffix == prefix {
        if suffixLen == 1, let char = suffix.first, !char.isPunctuation { continue }
        return newNS.substring(from: suffixLen)
      }
    }
    return newText
  }

  private func stripLeadingDuplicatePunctuation(_ text: String, at insertionPoint: Int) -> String {
    guard let storage = textView?.textStorage,
      insertionPoint > 0, !text.isEmpty
    else { return text }
    let prevChar = (storage.string as NSString).substring(
      with: NSRange(location: insertionPoint - 1, length: 1))
    let firstChar = String(text.prefix(1))
    if prevChar == firstChar, Character(firstChar).isPunctuation {
      return String(text.dropFirst())
    }
    return text
  }

  @discardableResult
  private func insertFinalizedText(_ text: String, at insertionPoint: Int) -> String {
    guard let textView, let storage = textView.textStorage else { return "" }
    let clampedPoint = min(insertionPoint, storage.length)
    let adjustedText = stripLeadingDuplicatePunctuation(text, at: clampedPoint)
    guard !adjustedText.isEmpty else {
      appState.inputText = textView.finalizedString
      return ""
    }
    let nsText = adjustedText as NSString
    textView.isSuppressingCallbacks = true
    storage.beginEditing()
    storage.insert(
      NSAttributedString(string: adjustedText, attributes: textView.typingAttributes),
      at: clampedPoint
    )
    storage.endEditing()
    textView.isSuppressingCallbacks = false
    voiceInsertionPoint = clampedPoint + nsText.length
    appState.inputText = textView.finalizedString
    return adjustedText
  }
}
