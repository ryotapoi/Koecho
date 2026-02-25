import AppKit
import os
import SwiftUI

@MainActor
final class InputPanelController {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "InputPanelController")
    private let appState: AppState
    private let selectedTextReader: any SelectedTextReading
    private let paster: any Pasting
    private let makeScriptRunner: () -> ScriptRunner
    private let historyStore: HistoryStore
    private var isConfirming = false
    private var isStoppingEngine = false
    private var engine: any VoiceInputEngine
    private let ducker: any VolumeDucking
    private var textView: VoiceInputTextView?
    private var voiceInsertionPoint: Int = 0
    private var currentVoiceTarget: VoiceTarget = .textEditor
    /// True after volatile text was locally finalized (e.g. by cursor movement
    /// or keyboard input). While set, SDK didFinalize is suppressed to prevent
    /// duplicate insertion. Cleared on the next didUpdateVolatile.
    private var isLocallyFinalized = false
    private(set) var panel: InputPanel

    enum VoiceTarget {
        case textEditor
        case prompt
    }

    init(
        appState: AppState,
        selectedTextReader: any SelectedTextReading,
        paster: any Pasting,
        makeScriptRunner: @escaping () -> ScriptRunner,
        historyStore: HistoryStore,
        ducker: any VolumeDucking
    ) {
        self.appState = appState
        self.selectedTextReader = selectedTextReader
        self.paster = paster
        self.makeScriptRunner = makeScriptRunner
        self.historyStore = historyStore
        self.ducker = ducker

        self.engine = DictationEngine()

        self.panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))

        let hostingView = NSHostingView(rootView: InputPanelContent(
            appState: appState,
            onExecuteScript: { [weak self] script in
                await self?.executeScript(script)
            },
            onCancelPrompt: { [weak self] in
                self?.cancelPrompt()
            },
            onApplyReplacementRules: { [weak self] in
                self?.applyOrPreviewReplacementRules()
            },
            onPromptFocused: { [weak self] in
                guard let self else { return }
                self.currentVoiceTarget = .prompt
                if let dictation = self.engine as? DictationEngine {
                    dictation.restart()
                }
            },
            onAddReplacementRule: { [weak self] rule in
                self?.addReplacementRule(rule)
            },
            onTextChanged: { [weak self] text in
                self?.handleTextChanged(text)
            },
            onTextCommitted: { [weak self] in
                self?.handleTextCommitted()
            },
            onTextViewCreated: { [weak self] view in
                guard let self else { return }
                self.textView = view
                view.onCursorMoved = { [weak self] position in
                    self?.handleCursorMoved(position)
                }
                view.onVolatileFinalized = { [weak self] in
                    self?.isLocallyFinalized = true
                }
                self.configureEngineWithTextView()
            },
            onFocusTextEditor: { [weak self] in
                self?.currentVoiceTarget = .textEditor
                self?.focusTextView()
            }
        ))
        panel.contentView = hostingView
        // Force SwiftUI layout so makeNSView runs and textView is created
        // before the first showPanel() call. This ensures textView is always
        // in the window hierarchy when clearTextView() runs.
        hostingView.layoutSubtreeIfNeeded()

        panel.onEscape = { [weak self] in
            guard let self else { return }
            if self.appState.promptScript != nil && !self.appState.isRunningScript {
                self.cancelPrompt()
            } else {
                self.cancel()
            }
        }

        panel.onShortcutKey = { [weak self] shortcut in
            guard let self else { return false }
            if let aShortcut = self.appState.settings.autoRunShortcutKey,
               shortcut == aShortcut {
                self.cycleAutoRunScript()
                return true
            }
            if let rShortcut = self.appState.settings.replacementShortcutKey,
               shortcut == rShortcut,
               !self.appState.settings.replacementRules.isEmpty {
                self.applyOrPreviewReplacementRules()
                return true
            }
            guard let script = self.appState.settings.scripts.first(where: { $0.shortcutKey == shortcut })
            else { return false }
            Task { @MainActor in
                await self.executeScript(script)
            }
            return true
        }

        panel.setFrameAutosaveName("InputPanel")
        if UserDefaults.standard.string(forKey: "NSWindow Frame InputPanel") == nil {
            panel.center()
        }
        logger.info("InputPanelController initialized")
    }

    convenience init(appState: AppState, historyStore: HistoryStore) {
        self.init(
            appState: appState,
            selectedTextReader: SelectedTextReader(),
            paster: ClipboardPaster(pasteDelay: appState.settings.pasteDelay),
            makeScriptRunner: { ScriptRunner(timeout: appState.settings.scriptTimeout) },
            historyStore: historyStore,
            ducker: OutputVolumeDucker(settings: appState.settings)
        )
    }

    func showPanel() {
        if appState.isInputPanelVisible {
            logger.debug("Panel already visible, refocusing")
            panel.makeKeyAndOrderFront(nil)
            return
        }

        appState.isRunningScript = false
        appState.frontmostApplication = NSWorkspace.shared.frontmostApplication
        logger.info("Recorded frontmost app: \(self.appState.frontmostApplication?.localizedName ?? "nil", privacy: .public)")

        if let app = appState.frontmostApplication {
            if let result = selectedTextReader.read(from: app.processIdentifier) {
                appState.selectedText = result.text
                appState.selectionStart = result.start
                appState.selectionEnd = result.end
                logger.info("Read selected text: \(result.text.count) chars")
            } else {
                appState.selectedText = ""
                appState.selectionStart = ""
                appState.selectionEnd = ""
            }
        } else {
            appState.selectedText = ""
            appState.selectionStart = ""
            appState.selectionEnd = ""
        }

        appState.inputText = appState.selectedText
        appState.errorMessage = nil
        appState.isInputPanelVisible = true
        ducker.duck()
        engine = makeEngine()
        voiceInsertionPoint = (appState.inputText as NSString).length
        currentVoiceTarget = .textEditor
        panel.makeKeyAndOrderFront(nil)
        clearTextView()

        logger.info("Panel shown, isKeyWindow: \(self.panel.isKeyWindow)")
    }

    private func clearTextView() {
        // layoutSubtreeIfNeeded in init ensures textView is always available
        // and in the window hierarchy. Fallback to async for safety.
        if let textView, textView.window != nil {
            textView.isSuppressingCallbacks = true
            textView.string = appState.inputText
            textView.isSuppressingCallbacks = false
            panel.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            textView.scrollRangeToVisible(textView.selectedRange())
            engine.start()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self, let textView = self.textView else { return }
                textView.isSuppressingCallbacks = true
                textView.string = self.appState.inputText
                textView.isSuppressingCallbacks = false
                if textView.window != nil {
                    self.panel.makeFirstResponder(textView)
                    textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
                    textView.scrollRangeToVisible(textView.selectedRange())
                }
                self.engine.start()
            }
        }
    }

    private func makeEngine() -> any VoiceInputEngine {
        if #available(macOS 26, *),
           appState.settings.effectiveVoiceInputMode == .speechAnalyzer {
            let locale = Locale(identifier: appState.settings.speechAnalyzerLocale)
            let engine = SpeechAnalyzerEngine(
                locale: locale,
                deviceUID: appState.settings.audioInputDeviceUID
            )
            engine.delegate = self
            return engine
        }
        let engine = DictationEngine()
        engine.configure(panel: panel, textView: textView)
        return engine
    }

    private func configureEngineWithTextView() {
        if let dictation = engine as? DictationEngine {
            dictation.configure(panel: panel, textView: textView)
        }
    }

    private func handleCursorMoved(_ position: Int) {
        guard !(engine is DictationEngine) else { return }
        if let textView, textView.volatileRange != nil {
            textView.finalizeVolatileText()
            isLocallyFinalized = true
            appState.inputText = textView.finalizedString
            if appState.settings.isAutoReplacementEnabled {
                applyOrPreviewReplacementRules()
            }
        }
        voiceInsertionPoint = position
    }

    func handleTextChanged(_ text: String) {
        // During Dictation (hasMarkedText), textView.string may include
        // hypothesis text that will be replaced on commit. Updating
        // appState.inputText here would cause duplicate text when Dictation
        // finalizes via insertText. Only update when no marked text.
        if let textView, !textView.hasMarkedText() {
            appState.inputText = text
        }
        appState.errorMessage = nil
        if appState.settings.isAutoReplacementEnabled {
            applyOrPreviewReplacementRules()
        }
    }

    private func handleTextCommitted() {
        // Dictation just committed marked text. Read the definitive string.
        if let textView {
            appState.inputText = textView.string
        }
        textView?.clearReplacementPreviews()
        if appState.settings.isAutoReplacementEnabled {
            applyOrPreviewReplacementRules()
        }
    }

    private func focusTextView() {
        guard let textView else { return }
        panel.makeFirstResponder(textView)
    }

    func executeScript(_ script: Script) async {
        guard appState.isInputPanelVisible,
              !isConfirming,
              !appState.isRunningScript,
              appState.promptScript == nil || appState.promptScript == script
        else { return }

        if script.requiresPrompt && appState.promptScript == nil {
            appState.errorMessage = nil
            appState.promptScript = script
            return
        }

        // Clear volatile text before script execution
        textView?.clearVolatileText()
        if let textView {
            let tvString = textView.finalizedString
            if !tvString.isEmpty {
                appState.inputText = tvString
            }
        }

        let originalText = appState.inputText
        appState.isRunningScript = true
        defer {
            appState.isRunningScript = false
            appState.promptScript = nil
            appState.promptText = ""
        }

        appState.errorMessage = nil

        let context = ScriptRunnerContext(
            selection: appState.selectedText,
            selectionStart: appState.selectionStart,
            selectionEnd: appState.selectionEnd,
            prompt: appState.promptText
        )

        let runner = makeScriptRunner()
        do {
            let result = try await runner.run(
                scriptPath: script.scriptPath,
                input: appState.inputText,
                context: context
            )
            guard appState.isInputPanelVisible else { return }
            appState.inputText = result.output
            voiceInsertionPoint = (result.output as NSString).length
        } catch {
            guard appState.isInputPanelVisible else { return }
            appState.inputText = originalText
            appState.errorMessage = scriptErrorMessage(for: error, script: script)
        }
    }

    private func applyOrPreviewReplacementRules() {
        guard appState.isInputPanelVisible,
              !appState.isRunningScript else { return }
        let rules = appState.settings.replacementRules
        guard !rules.isEmpty else { return }

        if let textView, textView.volatileRange != nil {
            // Volatile text present — suppress preview to avoid NSRange mismatch
            textView.clearReplacementPreviews()
        } else if let textView, textView.hasMarkedText() {
            showReplacementPreview(rules: rules)
        } else {
            applyReplacementRulesNow()
        }
    }

    private func showReplacementPreview(rules: [ReplacementRule]) {
        let currentText = textView?.string ?? ""
        guard !currentText.isEmpty else {
            textView?.clearReplacementPreviews()
            return
        }
        let matches = findReplacementMatches(rules, in: currentText)
        if matches.isEmpty {
            textView?.clearReplacementPreviews()
        } else {
            textView?.showReplacementPreviews(matches)
        }
    }

    func applyReplacementRulesNow() {
        guard appState.isInputPanelVisible,
              !appState.isRunningScript else { return }
        let rules = appState.settings.replacementRules
        guard !rules.isEmpty else { return }
        textView?.clearReplacementPreviews()
        let currentText = appState.inputText
        let result = applyReplacementRules(rules, to: currentText)
        if result != currentText {
            // Adjust voiceInsertionPoint based on replacement matches.
            // Sort by location and filter to original text bounds for stability.
            let currentNSLength = (currentText as NSString).length
            let matches = findReplacementMatches(rules, in: currentText)
                .filter { $0.range.location >= 0 && $0.range.location + $0.range.length <= currentNSLength }
                .sorted { $0.range.location < $1.range.location }
            var offset = 0
            for match in matches {
                let adjustedLocation = match.range.location + offset
                if adjustedLocation < voiceInsertionPoint {
                    let delta = (match.replacement as NSString).length - match.range.length
                    voiceInsertionPoint += delta
                    offset += delta
                }
            }
            voiceInsertionPoint = max(0, min(voiceInsertionPoint, (result as NSString).length))

            appState.inputText = result
            appState.errorMessage = nil
            if let textView {
                textView.isSuppressingCallbacks = true
                textView.string = result
                textView.isSuppressingCallbacks = false
            }
        }
    }

    func cancelPrompt() {
        currentVoiceTarget = .textEditor
        appState.promptScript = nil
        appState.promptText = ""
    }

    func confirm() async {
        guard appState.isInputPanelVisible, !isConfirming, !appState.isRunningScript else { return }

        textView?.clearReplacementPreviews()

        // For SpeechAnalyzer: stop engine and wait for final results
        isStoppingEngine = true
        await engine.stop()
        isStoppingEngine = false

        // Finalize any remaining volatile text (e.g. if stop() timed out)
        if textView?.volatileRange != nil {
            textView?.finalizeVolatileText()
        }

        // Read text: for SpeechAnalyzer use finalizedString, for Dictation use textView.string
        // Fall back to appState.inputText in test environment
        var rawText: String
        if let textView {
            // After stop + finalize, finalizedString == string (no volatile)
            let tvString = textView.finalizedString
            rawText = tvString.isEmpty ? appState.inputText : tvString
        } else {
            rawText = appState.inputText
        }

        // Clear text view so no content leaks to the foreground app.
        if let textView {
            textView.isSuppressingCallbacks = true
            textView.string = ""
            textView.isSuppressingCallbacks = false
        }

        // Apply replacement rules after Dictation is stopped
        let rules = appState.settings.replacementRules
        if !rules.isEmpty {
            rawText = applyReplacementRules(rules, to: rawText)
        }
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            paster.restoreClipboard()
            clearState()
            panel.orderOut(nil)
            logger.info("confirm() with empty text, treated as cancel")
            return
        }

        if let autoScript = appState.settings.autoRunScript {
            guard appState.isInputPanelVisible else { return }

            appState.inputText = text
            if let textView {
                textView.isSuppressingCallbacks = true
                textView.string = text
                textView.isSuppressingCallbacks = false
            }

            appState.isRunningScript = true
            defer { appState.isRunningScript = false }

            let context = ScriptRunnerContext(
                selection: appState.selectedText,
                selectionStart: appState.selectionStart,
                selectionEnd: appState.selectionEnd,
                prompt: ""
            )
            let runner = makeScriptRunner()
            do {
                let result = try await runner.run(
                    scriptPath: autoScript.scriptPath,
                    input: text,
                    context: context
                )
                guard appState.isInputPanelVisible else { return }
                text = result.output
            } catch {
                guard appState.isInputPanelVisible else { return }
                appState.inputText = text
                if let textView {
                    textView.isSuppressingCallbacks = true
                    textView.string = text
                    textView.isSuppressingCallbacks = false
                }
                appState.errorMessage = scriptErrorMessage(for: error, script: autoScript)
                return
            }
        }

        guard let targetApp = appState.frontmostApplication else {
            appState.errorMessage = "No target application"
            return
        }

        isConfirming = true
        defer { isConfirming = false }

        clearState()
        panel.orderOut(nil)

        do {
            try await paster.paste(text: text, to: targetApp, using: .general)
            historyStore.add(text: text, settings: appState.settings)
            logger.info("Paste completed successfully")
        } catch {
            paster.restoreClipboard()
            appState.isInputPanelVisible = true
            panel.makeKeyAndOrderFront(nil)
            appState.inputText = text
            appState.errorMessage = errorMessage(for: error)
            logger.error("Paste failed: \(error)")
        }
    }

    private func clearState() {
        textView?.clearReplacementPreviews()
        ducker.restore()
        appState.inputText = ""
        appState.isInputPanelVisible = false
        appState.frontmostApplication = nil
        appState.selectedText = ""
        appState.selectionStart = ""
        appState.selectionEnd = ""
        appState.errorMessage = nil
        appState.voiceEngineStatus = nil
        appState.isRunningScript = false
        appState.promptScript = nil
        appState.promptText = ""
        appState.pendingReplacementPattern = nil
        isLocallyFinalized = false
    }

    func cancel() {
        guard appState.isInputPanelVisible, !isConfirming else {
            logger.debug("cancel() ignored (not visible or confirming)")
            return
        }

        engine.cancel()
        paster.restoreClipboard()
        clearState()
        panel.orderOut(nil)

        logger.info("Panel cancelled and hidden")
    }

    /// Switch to a new engine while the panel is visible.
    /// Called when the user changes voiceInputMode in Settings.
    func switchEngine() async {
        guard appState.isInputPanelVisible, !isConfirming else { return }
        await engine.stop()
        textView?.clearVolatileText()
        if let textView {
            appState.inputText = textView.finalizedString
        }
        engine = makeEngine()
        voiceInsertionPoint = textView?.selectedRange().location ?? (appState.inputText as NSString).length
        engine.start()
        logger.info("Engine switched while panel visible")
    }

    private func errorMessage(for error: any Error) -> String {
        switch error {
        case ClipboardPasterError.accessibilityNotTrusted:
            "Accessibility permission required. Open System Settings > Privacy & Security > Accessibility."
        case ClipboardPasterError.targetAppTerminated:
            "Target application has been terminated."
        case ClipboardPasterError.failedToCreateCGEvent:
            "Failed to simulate paste keystroke."
        default:
            String(describing: error)
        }
    }

    private func scriptErrorMessage(for error: any Error, script: Script) -> String {
        switch error {
        case ScriptRunnerError.emptyScript:
            "Script command is empty."
        case ScriptRunnerError.timeout:
            "Script '\(script.name)' timed out."
        case ScriptRunnerError.nonZeroExit(let code, let stderr):
            "Script '\(script.name)' failed (exit \(code))\(stderr.isEmpty ? "" : ": \(stderr)")"
        case ScriptRunnerError.emptyOutput:
            "Script '\(script.name)' produced empty output."
        default:
            String(describing: error)
        }
    }

    func cycleAutoRunScript() {
        let eligible = appState.settings.scripts.filter { !$0.requiresPrompt }
        guard !eligible.isEmpty else {
            appState.settings.autoRunScriptId = nil
            return
        }
        if let currentId = appState.settings.autoRunScriptId,
           let idx = eligible.firstIndex(where: { $0.id == currentId }) {
            let next = idx + 1
            appState.settings.autoRunScriptId = next < eligible.count ? eligible[next].id : nil
        } else {
            appState.settings.autoRunScriptId = eligible[0].id
        }
    }

    func addReplacementRule(_ rule: ReplacementRule) {
        appState.settings.addReplacementRule(rule)
        appState.pendingReplacementPattern = nil
        applyOrPreviewReplacementRules()
    }
}

// MARK: - Voice text helpers

extension InputPanelController {
    /// Strip the first character of `text` if it duplicates the character at
    /// `insertionPoint - 1` and is punctuation. DictationTranscriber with
    /// `frequentFinalization` may include trailing punctuation from the previous
    /// segment at the start of the next segment.
    /// `insertionPoint` must already be clamped to storage bounds.
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

    /// Insert finalized voice text at the given position in the text storage.
    /// Updates `voiceInsertionPoint` to after the inserted text and syncs `appState.inputText`.
    private func insertFinalizedText(_ text: String, at insertionPoint: Int) {
        guard let textView, let storage = textView.textStorage else { return }
        let clampedPoint = min(insertionPoint, storage.length)
        let adjustedText = stripLeadingDuplicatePunctuation(text, at: clampedPoint)
        guard !adjustedText.isEmpty else {
            appState.inputText = textView.finalizedString
            return
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
    }
}

// MARK: - VoiceInputDelegate

extension InputPanelController: VoiceInputDelegate {
    func voiceInput(didFinalize text: String) {
        guard appState.isInputPanelVisible else { return }

        switch currentVoiceTarget {
        case .prompt:
            appState.promptText += text
            return
        case .textEditor:
            break
        }

        textView?.clearVolatileText()

        // Skip if the user already locally finalized (via cursor movement or
        // keyboard input). The flag is cleared by didUpdateVolatile when the
        // SDK starts recognizing new speech.
        if isLocallyFinalized { return }

        insertFinalizedText(text, at: voiceInsertionPoint)

        if !isStoppingEngine, appState.settings.isAutoReplacementEnabled {
            applyOrPreviewReplacementRules()
        }
    }

    func voiceInput(didUpdateVolatile text: String) {
        guard appState.isInputPanelVisible else { return }

        // A new volatile update means the SDK started recognizing new speech.
        if isLocallyFinalized { isLocallyFinalized = false }

        switch currentVoiceTarget {
        case .prompt:
            return
        case .textEditor:
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
}
