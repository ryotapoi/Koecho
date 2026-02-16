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
    private var isConfirming = false
    private(set) var panel: InputPanel

    init(
        appState: AppState,
        selectedTextReader: SelectedTextReader,
        paster: any Pasting,
        makeScriptRunner: @escaping () -> ScriptRunner
    ) {
        self.appState = appState
        self.selectedTextReader = selectedTextReader
        self.paster = paster
        self.makeScriptRunner = makeScriptRunner

        self.panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))

        let hostingView = NSHostingView(rootView: InputPanelContent(
            appState: appState,
            onExecuteScript: { [weak self] script in
                await self?.executeScript(script)
            },
            onCancelPrompt: { [weak self] in
                self?.cancelPrompt()
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

        panel.onShortcutKey = { [weak self] key in
            guard let self,
                  let script = self.appState.settings.scripts.first(where: { $0.shortcutKey == key })
            else { return false }
            Task { @MainActor in
                await self.executeScript(script)
            }
            return true
        }

        panel.center()
        logger.info("InputPanelController initialized")
    }

    convenience init(appState: AppState) {
        self.init(
            appState: appState,
            selectedTextReader: SelectedTextReader(),
            paster: ClipboardPaster(pasteDelay: appState.settings.pasteDelay),
            makeScriptRunner: { ScriptRunner(timeout: appState.settings.scriptTimeout) }
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
            self.panel.makeFirstResponder(textView)
        }
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

    func cancelPrompt() {
        appState.promptScript = nil
        appState.promptText = ""
    }

    func confirm() async {
        guard appState.isInputPanelVisible, !isConfirming, !appState.isRunningScript else { return }

        let text = appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            paster.restoreClipboard()
            clearState()
            panel.orderOut(nil)
            logger.info("confirm() with empty text, treated as cancel")
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
        case ScriptRunnerError.scriptNotFound(let path):
            "Script not found: \(path)"
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
}
