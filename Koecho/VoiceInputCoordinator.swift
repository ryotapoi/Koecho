import AppKit
import KoechoCore
import KoechoPlatform
import os

@MainActor
final class VoiceInputCoordinator: VoiceInputDelegate {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "VoiceInputCoordinator")
  private let appState: AppState
  private let makeEngine: () -> any VoiceInputEngine

  var textView: (any TextViewOperating)?

  private(set) var engine: any VoiceInputEngine
  private(set) var voiceInsertionPoint: Int = 0
  var currentVoiceTarget: VoiceTarget = .textEditor

  var localFinalizationState: LocalFinalizationState = .idle
  private var transcriberAlreadyRestarted = false
  private(set) var isStoppingEngine = false
  private var lifecycleID = UUID()
  private var inputSuspensionID: UUID?

  private var isInputSuspended: Bool { inputSuspensionID != nil }

  func suspendInput() -> UUID {
    let id = UUID()
    inputSuspensionID = id
    lifecycleID = UUID()
    restartTranscriberTask?.cancel()
    finalizeRemainingVolatile()
    return id
  }

  func finishSuspension(_ id: UUID, resume: Bool) {
    guard inputSuspensionID == id else { return }
    inputSuspensionID = nil
    isStoppingEngine = false
    currentVoiceTarget = .textEditor
    clearLocalFinalizationState()
    moveVoiceInsertionPoint(toEndOf: appState.inputText)
    if resume, appState.isInputPanelVisible, appState.settings.voiceInput.isVoiceInputEnabled {
      startEngine()
    }
  }
  private(set) var restartTranscriberTask: Task<Void, Never>?

  var onReplacementInput: (() -> Void)?
  var onCursorAutoReplacement: (() -> Void)?

  enum VoiceTarget {
    case textEditor
    case prompt
  }

  /// Keep volatile updates out of the editor while a local finalization awaits
  /// a transcriber restart. After restarting, recognition results flow unchanged.
  enum LocalFinalizationState {
    case idle
    case awaitingRestart
    case restarted

    mutating func record() {
      if self != .restarted { self = .awaitingRestart }
    }

    mutating func finishRestart() {
      if self != .idle { self = .restarted }
    }
  }

  init(
    appState: AppState,
    makeEngine: @escaping () -> any VoiceInputEngine
  ) {
    self.appState = appState
    self.makeEngine = makeEngine
    self.engine = makeEngine()
    self.engine.delegate = self
  }

  // MARK: - Engine lifecycle

  func startEngine() {
    guard !isInputSuspended, appState.settings.voiceInput.isVoiceInputEnabled else { return }
    engine.start()
  }

  func stopEngine() async {
    let id = lifecycleID
    isStoppingEngine = true
    await engine.stop()
    guard lifecycleID == id else { return }
    isStoppingEngine = false
  }

  func cancelEngine() {
    engine.delegate = nil
    engine.cancel()
  }

  func switchEngine() async {
    guard !isInputSuspended else { return }
    lifecycleID = UUID()
    let id = lifecycleID
    await engine.stop()
    guard lifecycleID == id, !isInputSuspended, appState.isInputPanelVisible,
      appState.settings.voiceInput.isVoiceInputEnabled
    else { return }
    textView?.clearVolatileText()
    if let textView {
      appState.setInputText(textView.finalizedString)
    }
    regenerateEngine()
    voiceInsertionPoint =
      textView?.selectedRange().location ?? (appState.inputText as NSString).length
    clearLocalFinalizationState()
    engine.start()
    logger.info("Engine switched while panel visible")
  }

  func disableEngine() async {
    lifecycleID = UUID()
    let id = lifecycleID
    await engine.stop()
    guard lifecycleID == id, !isInputSuspended, appState.isInputPanelVisible else { return }
    textView?.clearVolatileText()
    if let textView {
      appState.setInputText(textView.finalizedString)
    }
    clearLocalFinalizationState()
    logger.info("Engine disabled while panel visible")
  }

  func prepareForShow() {
    resetState()
    regenerateEngine()
    resetShowState()
  }

  private func resetShowState() {
    moveVoiceInsertionPoint(toEndOf: appState.inputText)
    currentVoiceTarget = .textEditor
    clearLocalFinalizationState()
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

  /// Finalize volatile editor text before a whole-document operation.
  /// Wait for the transcriber restart before displaying more volatile text.
  func finalizeVolatileForTextOperation() {
    guard let textView, let range = textView.volatileRange else {
      textView?.finalizeVolatileText()
      return
    }
    guard range.location + range.length <= (textView.string as NSString).length else {
      textView.clearVolatileText()
      return
    }

    textView.finalizeVolatileText()
    recordLocalFinalization()
    restartTranscriberIfNeeded()
  }

  func resetState() {
    lifecycleID = UUID()
    inputSuspensionID = nil
    isStoppingEngine = false
    restartTranscriberTask?.cancel()
    clearLocalFinalizationState()
  }

  // MARK: - Text editing hooks

  func handleCursorMoved(_ position: Int) {
    voiceInsertionPoint = position
    if let textView, textView.volatileRange != nil {
      if let range = textView.volatileRange,
        range.location + range.length <= (textView.string as NSString).length
      {
        textView.finalizeVolatileText()
        recordLocalFinalization()
      } else {
        textView.clearVolatileText()
      }
      appState.setInputText(textView.finalizedString)
      onCursorAutoReplacement?()
      restartTranscriberIfNeeded()
    }
  }

  func handleTextChanged() {
    restartTranscriberIfNeeded()
  }

  /// Record local finalization before the input operation restarts recognition.
  func recordLocalFinalization() {
    localFinalizationState.record()
  }

  // MARK: - VoiceInputDelegate

  func voiceInput(didFinalize text: String) {
    guard appState.isInputPanelVisible, !isInputSuspended else { return }

    switch currentVoiceTarget {
    case .prompt:
      transcriberAlreadyRestarted = false
      appState.volatilePromptText = ""
      appState.promptText += text
      return
    case .textEditor:
      break
    }

    textView?.clearVolatileText()

    clearLocalFinalizationState()

    guard !text.isEmpty else {
      if !isStoppingEngine { onReplacementInput?() }
      return
    }

    insertFinalizedText(text, at: voiceInsertionPoint)

    if !isStoppingEngine {
      onReplacementInput?()
    }
  }

  func voiceInput(didUpdateVolatile text: String) {
    guard appState.isInputPanelVisible, !isInputSuspended else { return }

    switch localFinalizationState {
    case .idle:
      break
    case .awaitingRestart:
      return
    case .restarted:
      clearLocalFinalizationState()
    }

    switch currentVoiceTarget {
    case .prompt:
      appState.volatilePromptText = text
      return
    case .textEditor:
      transcriberAlreadyRestarted = false
      if !text.isEmpty { textView?.clearReplacementPreviews() }
      textView?.setVolatileText(text, at: voiceInsertionPoint)
      if text.isEmpty { onReplacementInput?() }
      if textView?.volatileRange != nil {
        appState.discardScriptUndo()
      }
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
    engine.delegate = nil
    engine = makeEngine()
    engine.delegate = self
  }

  private func clearLocalFinalizationState() {
    localFinalizationState = .idle
    transcriberAlreadyRestarted = false
  }

  private func restartTranscriberIfNeeded() {
    guard !isInputSuspended, !transcriberAlreadyRestarted,
      let restartableEngine = engine as? any TranscriberRestartable
    else { return }
    let id = lifecycleID
    let hadLocalFinalization = localFinalizationState != .idle
    // Set synchronously to prevent duplicate Task creation from handleCursorMoved + handleTextChanged
    transcriberAlreadyRestarted = true
    restartTranscriberTask = Task { @MainActor in
      let didRestart = await restartableEngine.restartTranscriber()
      guard self.lifecycleID == id, !Task.isCancelled else { return }
      if didRestart {
        if hadLocalFinalization {
          self.localFinalizationState.finishRestart()
        }
      } else {
        // Restart failed (e.g. not listening): reset flag so next attempt can retry.
        // Don't clearLocalFinalizationState() here — a concurrent restart may be in flight.
        // localFinalizationState will be cleared by didFinalize or clearLocalFinalizationState elsewhere.
        self.transcriberAlreadyRestarted = false
      }
    }
  }

  private func insertFinalizedText(_ text: String, at insertionPoint: Int) {
    guard let textView else { return }
    let clampedPoint = min(insertionPoint, (textView.string as NSString).length)
    let insertedText = textView.insertFinalizedText(text, at: clampedPoint)
    let nsText = insertedText as NSString
    voiceInsertionPoint = clampedPoint + nsText.length
    appState.setInputText(textView.finalizedString)
  }
}
