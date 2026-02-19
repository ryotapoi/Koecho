import AppKit
import os
import SwiftUI

@MainActor
final class InputPanelController {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "InputPanelController")
    private let appState: AppState
    private let selectedTextReader: SelectedTextReader
    private let paster: any Pasting
    private let makeScriptRunner: () -> ScriptRunner
    private let historyStore: HistoryStore
    private var isConfirming = false
    private var shouldStartDictation = false
    private var dictationRetryWorkItem: DispatchWorkItem?
    private var textView: DictationTextView?
    private(set) var panel: InputPanel

    init(
        appState: AppState,
        selectedTextReader: SelectedTextReader,
        paster: any Pasting,
        makeScriptRunner: @escaping () -> ScriptRunner,
        historyStore: HistoryStore
    ) {
        self.appState = appState
        self.selectedTextReader = selectedTextReader
        self.paster = paster
        self.makeScriptRunner = makeScriptRunner
        self.historyStore = historyStore

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
                self?.applyReplacementRulesNow()
            },
            onPromptFocused: { [weak self] in
                guard let self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self, self.appState.promptScript != nil else { return }
                    self.startDictation()
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
                self?.textView = view
            },
            onFocusTextEditor: { [weak self] in
                self?.focusTextView()
            }
        ))
        panel.contentView = hostingView

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
            if let rShortcut = self.appState.settings.replacementShortcutKey,
               shortcut == rShortcut,
               !self.appState.settings.replacementRules.isEmpty {
                self.applyReplacementRulesNow()
                return true
            }
            guard let script = self.appState.settings.scripts.first(where: { $0.shortcutKey == shortcut })
            else { return false }
            Task { @MainActor in
                await self.executeScript(script)
            }
            return true
        }

        panel.center()
        logger.info("InputPanelController initialized")
    }

    convenience init(appState: AppState, historyStore: HistoryStore) {
        self.init(
            appState: appState,
            selectedTextReader: SelectedTextReader(),
            paster: ClipboardPaster(pasteDelay: appState.settings.pasteDelay),
            makeScriptRunner: { ScriptRunner(timeout: appState.settings.scriptTimeout) },
            historyStore: historyStore
        )
    }

    func showPanel() {
        if appState.isInputPanelVisible {
            logger.debug("Panel already visible, refocusing")
            panel.makeKeyAndOrderFront(nil)
            return
        }

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

        appState.inputText = ""
        appState.errorMessage = nil
        appState.isInputPanelVisible = true
        shouldStartDictation = true
        panel.makeKeyAndOrderFront(nil)
        clearTextView()

        logger.info("Panel shown, isKeyWindow: \(self.panel.isKeyWindow)")
    }

    private func clearTextView() {
        // onViewCreated is called in makeNSView, which may not have completed
        // layout yet on first show. Dispatch to next RunLoop cycle.
        if let textView {
            textView.isSuppressingCallbacks = true
            textView.string = ""
            textView.isSuppressingCallbacks = false
            panel.makeFirstResponder(textView)
            scheduleDictation()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self, let textView = self.textView else { return }
                textView.isSuppressingCallbacks = true
                textView.string = ""
                textView.isSuppressingCallbacks = false
                self.panel.makeFirstResponder(textView)
                self.scheduleDictation()
            }
        }
    }

    private func scheduleDictation() {
        guard shouldStartDictation else { return }
        shouldStartDictation = false
        let workItem = DispatchWorkItem { [weak self] in
            self?.startDictation()
        }
        dictationRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func stopDictation() async {
        guard let textView else { return }
        textView.inputContext?.discardMarkedText()
        panel.makeFirstResponder(nil)
        // Give macOS time to finalize the Dictation session.
        try? await Task.sleep(for: .milliseconds(100))
        // Clear text view so no content leaks to the foreground app.
        textView.isSuppressingCallbacks = true
        textView.string = ""
        textView.isSuppressingCallbacks = false
    }

    private func startDictation() {
        guard appState.isInputPanelVisible else { return }

        let selector = Selector(("startDictation:"))
        if !NSApp.sendAction(selector, to: nil, from: nil) {
            textView?.perform(selector, with: nil)
        }
        logger.debug("startDictation sent")
    }

    private func handleTextChanged(_ text: String) {
        appState.inputText = text
        appState.errorMessage = nil
    }

    private func handleTextCommitted() {
        logger.debug("Dictation text committed")
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
        } catch {
            guard appState.isInputPanelVisible else { return }
            appState.inputText = originalText
            appState.errorMessage = scriptErrorMessage(for: error, script: script)
        }
    }

    func applyReplacementRulesNow() {
        guard appState.isInputPanelVisible,
              !appState.isRunningScript else { return }
        let rules = appState.settings.replacementRules
        guard !rules.isEmpty else { return }
        if let textView, textView.hasMarkedText() {
            logger.debug("Skipping replacement rules: text view has marked text")
            return
        }
        let currentText = appState.inputText
        let result = applyReplacementRules(rules, to: currentText)
        if result != currentText {
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
        appState.promptScript = nil
        appState.promptText = ""
    }

    func confirm() async {
        guard appState.isInputPanelVisible, !isConfirming, !appState.isRunningScript else { return }
        dictationRetryWorkItem?.cancel()
        dictationRetryWorkItem = nil

        let rawText = appState.inputText

        await stopDictation()
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            paster.restoreClipboard()
            clearState()
            panel.orderOut(nil)
            logger.info("confirm() with empty text, treated as cancel")
            return
        }
        let text: String
        if appState.settings.appliesReplacementRulesOnConfirm {
            text = applyReplacementRules(appState.settings.replacementRules, to: trimmed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            text = trimmed
        }
        guard !text.isEmpty else {
            paster.restoreClipboard()
            clearState()
            panel.orderOut(nil)
            logger.info("confirm() replacement rules emptied text, treated as cancel")
            return
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
        shouldStartDictation = false
        dictationRetryWorkItem?.cancel()
        dictationRetryWorkItem = nil
        appState.inputText = ""
        appState.isInputPanelVisible = false
        appState.frontmostApplication = nil
        appState.selectedText = ""
        appState.selectionStart = ""
        appState.selectionEnd = ""
        appState.errorMessage = nil
        appState.isRunningScript = false
        appState.promptScript = nil
        appState.promptText = ""
        appState.pendingReplacementPattern = nil
    }

    func cancel() {
        guard appState.isInputPanelVisible, !isConfirming else {
            logger.debug("cancel() ignored (not visible or confirming)")
            return
        }

        paster.restoreClipboard()
        clearState()
        panel.orderOut(nil)

        logger.info("Panel cancelled and hidden")
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

    func addReplacementRule(_ rule: ReplacementRule) {
        appState.settings.addReplacementRule(rule)
        appState.pendingReplacementPattern = nil
        applyReplacementRulesNow()
    }
}
