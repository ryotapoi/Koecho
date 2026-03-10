import AppKit
import os
import KoechoCore
import KoechoPlatform

@MainActor
final class VoiceInputCoordinator: VoiceInputDelegate {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "VoiceInputCoordinator")
    private let appState: AppState
    private let makeEngine: () -> any VoiceInputEngine
    private let panel: InputPanel

    var textView: (any TextViewOperating)?

    private(set) var engine: any VoiceInputEngine
    var voiceInsertionPoint: Int = 0
    var currentVoiceTarget: VoiceTarget = .textEditor

    var isLocallyFinalized = false
    var localFinalizedText: String?
    private var accumulatedFinalizedText: String = ""
    private static let replaySuppressionDuration: TimeInterval = 2.0
    var replaySuppressionDeadline: Date?
    private var transcriberAlreadyRestarted = false
    private(set) var isStoppingEngine = false

    var onAutoReplacement: (() -> Void)?
    var onCursorAutoReplacement: (() -> Void)?

    enum VoiceTarget {
        case textEditor
        case prompt
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
        voiceInsertionPoint = textView?.selectedRange().location ?? (appState.inputText as NSString).length
        clearReplayState()
        accumulatedFinalizedText = ""
        engine.start()
        logger.info("Engine switched while panel visible")
    }

    func prepareForShow() {
        regenerateEngine()
        voiceInsertionPoint = (appState.inputText as NSString).length
        currentVoiceTarget = .textEditor
        clearReplayState()
        accumulatedFinalizedText = ""
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
           let tv = textView as? VoiceInputTextView {
            dictation.configure(panel: panel, textView: tv)
        }
    }

    // MARK: - Text editing hooks

    func handleCursorMoved(_ position: Int) {
        guard !(engine is DictationEngine) else { return }
        if let textView, textView.volatileRange != nil {
            if let range = textView.volatileRange,
               range.location + range.length <= (textView.string as NSString).length {
                let volatileText = (textView.string as NSString).substring(with: range)
                textView.finalizeVolatileText()
                isLocallyFinalized = true
                localFinalizedText = volatileText
            } else {
                textView.clearVolatileText()
            }
            appState.inputText = textView.finalizedString
            onCursorAutoReplacement?()
        }
        voiceInsertionPoint = position
    }

    func handleTextChanged() {
        restartTranscriberIfNeeded()
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

        if isLocallyFinalized {
            let localText = localFinalizedText
            let isReplayContext = replaySuppressionDeadline != nil
            clearReplayState()

            if isReplayContext, let localText {
                if text == localText {
                    accumulatedFinalizedText += localText
                    return
                }
                let newText = stripOverlappingPrefix(text, accumulated: accumulatedFinalizedText + localText)
                if newText.isEmpty {
                    accumulatedFinalizedText += localText
                    return
                }
                accumulatedFinalizedText += localText
                let inserted = insertFinalizedText(newText, at: voiceInsertionPoint)
                accumulatedFinalizedText += inserted
                if !isStoppingEngine, appState.settings.replacement.isAutoReplacementEnabled {
                    onAutoReplacement?()
                }
                return
            }

            accumulatedFinalizedText += localText ?? ""
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

        if let deadline = replaySuppressionDeadline, Date.now < deadline {
            if currentVoiceTarget == .textEditor,
               let localText = localFinalizedText,
               localText.hasPrefix(text) || text.hasPrefix(localText) {
                return
            }
            if isLocallyFinalized { clearReplayState() }
        } else if isLocallyFinalized {
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

    func voiceInput(didEncounterError message: String) {
        appState.errorMessage = message
    }

    func voiceInput(didUpdateStatus status: String?) {
        appState.voiceEngineStatus = status
    }

    // MARK: - Private helpers

    private func regenerateEngine() {
        engine = makeEngine()
        engine.delegate = self
        configureEngineWithTextView()
    }

    private func clearReplayState() {
        isLocallyFinalized = false
        localFinalizedText = nil
        replaySuppressionDeadline = nil
        transcriberAlreadyRestarted = false
    }

    private func restartTranscriberIfNeeded() {
        if #available(macOS 26, *) {
            guard !transcriberAlreadyRestarted,
                  let saEngine = engine as? SpeechAnalyzerEngine else { return }
            let shouldSuppressReplay = isLocallyFinalized
            Task { @MainActor in
                let didRestart = await saEngine.restartTranscriber()
                if didRestart {
                    self.transcriberAlreadyRestarted = true
                    if shouldSuppressReplay {
                        self.replaySuppressionDeadline = Date.now + Self.replaySuppressionDuration
                    }
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
              insertionPoint > 0, !text.isEmpty else { return text }
        let prevChar = (storage.string as NSString).substring(with: NSRange(location: insertionPoint - 1, length: 1))
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
