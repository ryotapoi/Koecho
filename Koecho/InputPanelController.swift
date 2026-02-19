import AppKit
import ObjectiveC
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
        // On first show, NSTextView may not exist yet in the view hierarchy.
        // Dispatch to next RunLoop cycle to let NSHostingView complete layout.
        DispatchQueue.main.async { [weak self] in
            guard let self, let textView = self.findTextView(in: self.panel.contentView) else { return }
            textView.string = ""
            self.setupTextViewContextMenu(textView)
            self.panel.makeFirstResponder(textView)

            guard self.shouldStartDictation else { return }
            self.shouldStartDictation = false
            let workItem = DispatchWorkItem { [weak self] in
                self?.startDictation()
            }
            self.dictationRetryWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }

    /// Stop Dictation if active, and wait for the system to finish
    /// committing any pending text to the text view. Without this delay,
    /// macOS may forward the dictated text to the foreground app when the
    /// panel loses focus.
    private func stopDictation() async {
        guard let textView = findTextView(in: panel.contentView) else { return }
        textView.inputContext?.discardMarkedText()
        panel.makeFirstResponder(nil)
        // Give macOS time to finalize the Dictation session.
        try? await Task.sleep(for: .milliseconds(100))
        // Clear text view so no content leaks to the foreground app.
        textView.string = ""
    }

    /// Read the current text directly from the NSTextView in the panel.
    /// TextEditor's binding may lag behind the actual NSTextView content
    /// while the text view has focus, so this ensures we get the real text.
    private func readTextViewString() -> String? {
        findTextView(in: panel.contentView)?.string
    }

    /// Send `startDictation:` once via the responder chain.
    ///
    /// Does NOT retry — `startDictation:` acts as a toggle, so re-sending
    /// while Dictation is active would stop it.
    private func startDictation() {
        guard appState.isInputPanelVisible else { return }

        let selector = Selector(("startDictation:"))
        if !NSApp.sendAction(selector, to: nil, from: nil) {
            // Fallback: send directly to text view for .nonactivatingPanel
            if let textView = findTextView(in: panel.contentView) {
                textView.perform(selector, with: nil)
            }
        }
        logger.debug("startDictation sent")
    }

    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView {
            return textView
        }
        for subview in view.subviews {
            if let found = findTextView(in: subview) {
                return found
            }
        }
        return nil
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
        // Dictation の marked text 中に textView.string を書き換えると
        // 未確定テキストが消失するため、marked text がある間はスキップ
        if let textView = findTextView(in: panel.contentView),
           textView.hasMarkedText() {
            logger.debug("Skipping replacement rules: text view has marked text")
            return
        }
        let currentText = readTextViewString() ?? appState.inputText
        let result = applyReplacementRules(rules, to: currentText)
        if result != currentText {
            appState.inputText = result
            if let textView = findTextView(in: panel.contentView) {
                textView.string = result
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

        // Read text BEFORE stopping Dictation, because stopDictation()
        // clears the text view to prevent content leaking to foreground app.
        let rawText = readTextViewString() ?? appState.inputText

        // Stop Dictation before closing the panel. If Dictation is active
        // when the panel closes (orderOut), macOS transfers the dictated
        // text to the foreground app via NSInputAnalytics, causing
        // duplicated text at the paste target.
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

        // Clear state immediately so next togglePanel sees a clean slate
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

    // MARK: - Context Menu

    private static var controllerKey: UInt8 = 0

    private func setupTextViewContextMenu(_ textView: NSTextView) {
        let className = NSStringFromClass(type(of: textView))
        guard !className.hasPrefix("Koecho_") else { return }

        objc_setAssociatedObject(
            textView,
            &Self.controllerKey,
            self,
            .OBJC_ASSOCIATION_ASSIGN
        )

        let originalClass: AnyClass = type(of: textView)
        let subclassName = "Koecho_\(className)"

        if let subclass = objc_allocateClassPair(originalClass, subclassName, 0) {
            let menuSelector = #selector(NSView.menu(for:))
            let menuMethod = class_getInstanceMethod(originalClass, menuSelector)!
            let menuTypes = method_getTypeEncoding(menuMethod)

            let block: @convention(block) (NSTextView, NSEvent) -> NSMenu? = { textView, event in
                let original = unsafeBitCast(
                    class_getMethodImplementation(originalClass, menuSelector),
                    to: (@convention(c) (NSTextView, Selector, NSEvent) -> NSMenu?).self
                )
                let menu = original(textView, menuSelector, event)

                guard textView.selectedRange().length > 0 else { return menu }

                menu?.addItem(.separator())
                let item = NSMenuItem(
                    title: "Add Replacement Rule…",
                    action: #selector(InputPanelController.addReplacementRuleFromMenu(_:)),
                    keyEquivalent: ""
                )
                let controller = objc_getAssociatedObject(textView, &InputPanelController.controllerKey)
                item.target = controller as AnyObject?
                menu?.addItem(item)

                return menu
            }
            let imp = imp_implementationWithBlock(block as Any)
            class_addMethod(subclass, menuSelector, imp, menuTypes)
            objc_registerClassPair(subclass)
            object_setClass(textView, subclass)
        } else if let existingSubclass = objc_lookUpClass(subclassName) {
            object_setClass(textView, existingSubclass)
        } else {
            logger.warning("Failed to create dynamic subclass for NSTextView")
            return
        }

        logger.debug("Set up context menu for NSTextView")
    }

    @objc func addReplacementRuleFromMenu(_ sender: Any?) {
        guard let textView = findTextView(in: panel.contentView) else { return }
        let range = textView.selectedRange()
        guard range.length > 0,
              let string = textView.string as NSString?,
              range.location + range.length <= string.length
        else { return }
        let selectedText = string.substring(with: range)
        appState.pendingReplacementPattern = selectedText
    }

    func addReplacementRule(_ rule: ReplacementRule) {
        appState.settings.addReplacementRule(rule)
        appState.pendingReplacementPattern = nil
        applyReplacementRulesNow()
    }
}
