import AppKit
import os
import SwiftUI
import KoechoCore
import KoechoPlatform

@MainActor
final class InputPanelController {
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "InputPanelController")
    private let appState: AppState
    private let paster: any Pasting
    private let historyStore: HistoryStore
    private var isConfirming = false
    private var textView: VoiceInputTextView?
    private(set) var panel: InputPanel
    private var replacementService: ReplacementService!
    private var scriptService: ScriptExecutionService!
    private var voiceCoordinator: VoiceInputCoordinator!
    private var lifecycleManager: PanelLifecycleManager!

    init(
        appState: AppState,
        selectedTextReader: any SelectedTextReading,
        paster: any Pasting,
        makeScriptRunner: @escaping () -> ScriptRunner,
        makeEngine: (() -> any VoiceInputEngine)? = nil,
        historyStore: HistoryStore,
        ducker: any VolumeDucking
    ) {
        self.appState = appState
        self.paster = paster
        self.historyStore = historyStore

        self.panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))

        self.lifecycleManager = PanelLifecycleManager(
            appState: appState,
            selectedTextReader: selectedTextReader,
            ducker: ducker,
            panel: panel
        )

        let engineFactory = makeEngine ?? { () -> any VoiceInputEngine in
            if #available(macOS 26, *),
               appState.settings.voiceInput.effectiveVoiceInputMode == .speechAnalyzer {
                let locale = Locale(identifier: appState.settings.voiceInput.speechAnalyzerLocale)
                return SpeechAnalyzerEngine(
                    locale: locale,
                    deviceUID: appState.settings.voiceInput.audioInputDeviceUID
                )
            }
            return DictationEngine()
        }

        self.voiceCoordinator = VoiceInputCoordinator(
            appState: appState,
            makeEngine: engineFactory,
            panel: panel
        )

        self.replacementService = ReplacementService(
            appState: appState,
            getVoiceInsertionPoint: { [weak self] in self?.voiceCoordinator.voiceInsertionPoint ?? 0 },
            setVoiceInsertionPoint: { [weak self] in self?.voiceCoordinator.voiceInsertionPoint = $0 }
        )

        self.scriptService = ScriptExecutionService(
            appState: appState,
            makeScriptRunner: makeScriptRunner,
            setVoiceInsertionPoint: { [weak self] in self?.voiceCoordinator.voiceInsertionPoint = $0 },
            isConfirming: { [weak self] in self?.isConfirming ?? false }
        )

        voiceCoordinator.onAutoReplacement = { [weak self] in
            self?.replacementService.applyOrPreview()
        }
        voiceCoordinator.onCursorAutoReplacement = { [weak self] in
            guard let self, self.appState.settings.replacement.isAutoReplacementEnabled else { return }
            self.replacementService.applyOrPreview()
        }

        let hostingView = NSHostingView(rootView: InputPanelContent(
            appState: appState,
            onExecuteScript: { [weak self] script in
                await self?.scriptService.execute(script)
            },
            onCancelPrompt: { [weak self] in
                self?.cancelPrompt()
            },
            onApplyReplacementRules: { [weak self] in
                self?.replacementService.applyOrPreview()
            },
            onPromptFocused: { [weak self] in
                guard let self else { return }
                self.voiceCoordinator.currentVoiceTarget = .prompt
                self.voiceCoordinator.restartDictationIfNeeded()
            },
            onAddReplacementRule: { [weak self] rule in
                self?.replacementService.addRule(rule)
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
                self.voiceCoordinator.textView = view
                self.replacementService.textView = view
                self.scriptService.textView = view
                view.onCursorMoved = { [weak self] position in
                    self?.voiceCoordinator.handleCursorMoved(position)
                }
                view.onVolatileFinalized = { [weak self] volatileText in
                    guard let self else { return }
                    self.voiceCoordinator.isLocallyFinalized = true
                    self.voiceCoordinator.localFinalizedText = volatileText
                }
                self.voiceCoordinator.configureEngineWithTextView()
            },
            onFocusTextEditor: { [weak self] in
                self?.voiceCoordinator.currentVoiceTarget = .textEditor
                self?.focusTextView()
            }
        ))
        panel.contentView = hostingView
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
            if let aShortcut = self.appState.settings.script.autoRunShortcutKey,
               shortcut == aShortcut {
                self.scriptService.cycleAutoRunScript()
                return true
            }
            if let rShortcut = self.appState.settings.replacement.replacementShortcutKey,
               shortcut == rShortcut,
               !self.appState.settings.replacement.replacementRules.isEmpty {
                self.replacementService.applyOrPreview()
                return true
            }
            guard let script = self.appState.settings.script.scripts.first(where: { $0.shortcutKey == shortcut })
            else { return false }
            Task { @MainActor in
                await self.scriptService.execute(script)
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
            paster: ClipboardPaster(pasteDelay: appState.settings.paste.pasteDelay),
            makeScriptRunner: { ScriptRunner(timeout: appState.settings.script.scriptTimeout) },
            historyStore: historyStore,
            ducker: OutputVolumeDucker(settings: appState.settings.volumeDucking)
        )
    }

    // MARK: - Panel lifecycle

    func showPanel() {
        if appState.isInputPanelVisible {
            logger.debug("Panel already visible, refocusing")
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let voiceEnabled = appState.settings.voiceInput.effectiveVoiceInputMode != .off
        lifecycleManager.show(duckVolume: voiceEnabled)
        if voiceEnabled {
            voiceCoordinator.prepareForShow()
        } else {
            voiceCoordinator.prepareForShowWithoutEngine()
        }
        clearTextView(startEngine: voiceEnabled)

        logger.info("Panel shown, isKeyWindow: \(self.panel.isKeyWindow)")
    }

    func confirm() async {
        guard appState.isInputPanelVisible, !isConfirming, !appState.isRunningScript else { return }

        replacementService.clearPreviews()

        await voiceCoordinator.stopEngine()

        voiceCoordinator.finalizeRemainingVolatile()

        var rawText: String
        if let textView {
            let tvString = textView.finalizedString
            rawText = tvString.isEmpty ? appState.inputText : tvString
        } else {
            rawText = appState.inputText
        }

        textView?.setString("", suppressingCallbacks: true)

        rawText = replacementService.applyRules(to: rawText)
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            paster.restoreClipboard()
            voiceCoordinator.resetState()
            lifecycleManager.clearState()
            lifecycleManager.hide()
            logger.info("confirm() with empty text, treated as cancel")
            return
        }

        if let autoScript = appState.settings.script.autoRunScript {
            guard appState.isInputPanelVisible else { return }

            appState.inputText = text
            textView?.setString(text, suppressingCallbacks: true)

            appState.isRunningScript = true
            defer { appState.isRunningScript = false }

            do {
                text = try await scriptService.runAutoScript(autoScript, on: text)
                guard appState.isInputPanelVisible else { return }
            } catch {
                guard appState.isInputPanelVisible else { return }
                appState.inputText = text
                textView?.setString(text, suppressingCallbacks: true)
                appState.errorMessage = scriptService.scriptErrorMessage(for: error, script: autoScript)
                return
            }
        }

        guard let targetApp = appState.frontmostApplication else {
            appState.errorMessage = "No target application"
            return
        }

        isConfirming = true
        defer { isConfirming = false }

        voiceCoordinator.resetState()
        lifecycleManager.clearState()
        lifecycleManager.hide()

        do {
            try await paster.paste(text: text, to: targetApp, using: .general)
            historyStore.add(text: text, settings: appState.settings.history)
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

    func cancel() {
        guard appState.isInputPanelVisible, !isConfirming else {
            logger.debug("cancel() ignored (not visible or confirming)")
            return
        }

        voiceCoordinator.cancelEngine()
        paster.restoreClipboard()
        voiceCoordinator.resetState()
        replacementService.clearPreviews()
        lifecycleManager.clearState()
        lifecycleManager.hide()

        logger.info("Panel cancelled and hidden")
    }

    func switchEngine() async {
        guard appState.isInputPanelVisible, !isConfirming else { return }
        await voiceCoordinator.switchEngine()
    }

    // MARK: - Text editing

    func handleTextChanged(_ text: String) {
        if let textView, !textView.hasMarkedText() {
            appState.inputText = text
        }
        appState.errorMessage = nil
        if appState.settings.replacement.isAutoReplacementEnabled {
            replacementService.applyOrPreview()
        }
        voiceCoordinator.handleTextChanged()
    }

    func applyReplacementRulesNow() {
        replacementService.applyNow()
    }

    func addReplacementRule(_ rule: ReplacementRule) {
        replacementService.addRule(rule)
    }

    func executeScript(_ script: Script) async {
        await scriptService.execute(script)
    }

    func cancelPrompt() {
        voiceCoordinator.currentVoiceTarget = .textEditor
        scriptService.cancelPrompt()
    }

    func cycleAutoRunScript() {
        scriptService.cycleAutoRunScript()
    }

    // MARK: - VoiceInputDelegate forwarding

    func voiceInput(didFinalize text: String) {
        voiceCoordinator.voiceInput(didFinalize: text)
    }

    func voiceInput(didUpdateVolatile text: String) {
        voiceCoordinator.voiceInput(didUpdateVolatile: text)
    }

    func voiceInput(didEncounterError message: String) {
        voiceCoordinator.voiceInput(didEncounterError: message)
    }

    func voiceInput(didUpdateStatus status: String?) {
        voiceCoordinator.voiceInput(didUpdateStatus: status)
    }

    // MARK: - Computed property forwarding

    var isLocallyFinalized: Bool {
        get { voiceCoordinator.isLocallyFinalized }
        set { voiceCoordinator.isLocallyFinalized = newValue }
    }

    var localFinalizedText: String? {
        get { voiceCoordinator.localFinalizedText }
        set { voiceCoordinator.localFinalizedText = newValue }
    }

    var replaySuppressionDeadline: Date? {
        get { voiceCoordinator.replaySuppressionDeadline }
        set { voiceCoordinator.replaySuppressionDeadline = newValue }
    }

    // MARK: - Private

    private func handleTextCommitted() {
        if let textView {
            appState.inputText = textView.string
        }
        replacementService.clearPreviews()
        if appState.settings.replacement.isAutoReplacementEnabled {
            replacementService.applyOrPreview()
        }
    }

    private func focusTextView() {
        guard let textView else { return }
        textView.makeFirstResponder(in: panel)
    }

    private func clearTextView(startEngine: Bool = true) {
        if let textView, textView.window != nil {
            textView.setString(appState.inputText, suppressingCallbacks: true)
            textView.makeFirstResponder(in: panel)
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            textView.scrollRangeToVisible(textView.selectedRange())
            if startEngine {
                voiceCoordinator.startEngine()
            }
        } else {
            Task { [weak self] in
                guard let self, let textView = self.textView else { return }
                textView.setString(self.appState.inputText, suppressingCallbacks: true)
                if textView.window != nil {
                    textView.makeFirstResponder(in: self.panel)
                    textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
                    textView.scrollRangeToVisible(textView.selectedRange())
                }
                if startEngine {
                    self.voiceCoordinator.startEngine()
                }
            }
        }
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

}
