import AppKit
import Foundation
import Testing
@testable import Koecho

@MainActor
private final class MockPaster: Pasting {
    var pastedTexts: [String] = []
    var errorToThrow: (any Error)?
    var restoreClipboardCallCount = 0
    var onPaste: (() async -> Void)?

    func paste(text: String, to application: NSRunningApplication, using pasteboard: NSPasteboard) async throws {
        if let error = errorToThrow {
            throw error
        }
        if let onPaste {
            await onPaste()
        }
        pastedTexts.append(text)
    }

    func restoreClipboard() {
        restoreClipboardCallCount += 1
    }
}

@MainActor
private func makeController(
    paster: MockPaster? = nil,
    makeScriptRunner: (() -> ScriptRunner)? = nil
) -> (InputPanelController, AppState, MockPaster) {
    let p = paster ?? MockPaster()
    let appState = AppState()
    let reader = SelectedTextReader()
    let controller = InputPanelController(
        appState: appState,
        selectedTextReader: reader,
        paster: p,
        makeScriptRunner: makeScriptRunner ?? { ScriptRunner(timeout: appState.settings.scriptTimeout) }
    )
    return (controller, appState, p)
}

@MainActor
private func makeScript(_ content: String) throws -> String {
    let dir = FileManager.default.temporaryDirectory
    let path = dir.appendingPathComponent("koecho-test-\(UUID().uuidString).sh").path
    try ("#!/bin/sh\n" + content).write(toFile: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: path
    )
    return path
}

@MainActor
struct InputPanelControllerTests {
    @Test func showPanelSetsState() {
        let (controller, appState, _) = makeController()

        controller.showPanel()

        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "")
        #expect(controller.panel.isVisible)
    }

    @Test func cancelClearsState() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "some text"
        controller.cancel()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(appState.frontmostApplication == nil)
        #expect(!controller.panel.isVisible)
    }

    @Test func closeButtonCancelsPanel() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "some text"
        controller.panel.close()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
    }

    @Test func cancelClearsSelectedText() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.selectedText = "selected"
        appState.selectionStart = "0"
        appState.selectionEnd = "8"
        controller.cancel()

        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
    }

    @Test func cancelClearsTextAfterInput() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello world"
        controller.cancel()

        #expect(appState.inputText == "")
    }

    @Test func showPanelTwicePreservesText() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello"
        controller.showPanel()

        #expect(appState.inputText == "hello")
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func cancelWhenNotVisibleIsNoop() {
        let (controller, appState, _) = makeController()

        controller.cancel()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
    }

    @Test func showCancelShowCycle() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        #expect(appState.isInputPanelVisible == true)

        controller.cancel()
        #expect(appState.isInputPanelVisible == false)

        controller.showPanel()
        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "")
        #expect(controller.panel.isVisible)
    }

    // MARK: - confirm tests

    @Test func confirmSuccessClearsState() async {
        let paster = MockPaster()
        let (controller, appState, _) = makeController(paster: paster)

        controller.showPanel()
        appState.inputText = "hello"
        // Set a fake frontmost app — use current app as a stand-in
        appState.frontmostApplication = NSRunningApplication.current

        await controller.confirm()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(appState.frontmostApplication == nil)
        #expect(appState.selectedText == "")
        #expect(appState.errorMessage == nil)
        #expect(paster.pastedTexts == ["hello"])
    }

    @Test func confirmFailureShowsError() async {
        let paster = MockPaster()
        paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
        let (controller, appState, _) = makeController(paster: paster)

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = NSRunningApplication.current

        await controller.confirm()

        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "hello")
        #expect(appState.errorMessage != nil)
        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func confirmWithEmptyTextActsAsCancel() async {
        let (controller, appState, paster) = makeController()

        controller.showPanel()
        appState.inputText = "   \n  "

        await controller.confirm()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func confirmWhenNotVisibleIsNoop() async {
        let paster = MockPaster()
        let (controller, _, _) = makeController(paster: paster)

        await controller.confirm()

        #expect(paster.pastedTexts.isEmpty)
    }

    @Test func confirmWithNoTargetAppSetsError() async {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = nil

        await controller.confirm()

        #expect(appState.errorMessage == "No target application")
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func cancelDuringConfirmIsIgnored() async {
        let paster = MockPaster()
        let (controller, appState, _) = makeController(paster: paster)

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = NSRunningApplication.current

        // Make paste suspend so we can call cancel() while confirm() is in progress
        paster.onPaste = {
            // Yield to allow cancel() to be attempted on the same actor
            await Task.yield()
        }

        // Start confirm in a Task so we can call cancel() after it begins
        let confirmTask = Task { @MainActor in
            await controller.confirm()
        }
        // Yield to let confirmTask start and reach the onPaste suspension
        await Task.yield()

        // Panel should be hidden (confirm hides it before paste) but isConfirming is true
        // cancel() should be ignored because isConfirming is true
        controller.cancel()

        await confirmTask.value

        // Confirm should have succeeded — cancel was ignored
        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(paster.pastedTexts == ["hello"])
    }

    @Test func showPanelClearsSelectedText() {
        let (controller, appState, _) = makeController()

        // Simulate leftover selected text from a previous session
        appState.selectedText = "old selection"
        appState.selectionStart = "5"
        appState.selectionEnd = "18"

        controller.showPanel()

        // In test environment, SelectedTextReader returns nil, so these should be cleared
        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
    }

    @Test func cancelCallsRestoreClipboard() {
        let paster = MockPaster()
        let (controller, _, _) = makeController(paster: paster)

        controller.showPanel()
        controller.cancel()

        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func showPanelClearsErrorMessage() {
        let (controller, appState, _) = makeController()

        appState.errorMessage = "previous error"
        controller.showPanel()

        #expect(appState.errorMessage == nil)
    }

    // MARK: - executeScript tests

    @Test func executeScriptReplacesText() async throws {
        let scriptPath = try makeScript("tr a-z A-Z")
        let script = Script(name: "Upper", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello"

        await controller.executeScript(script)

        #expect(appState.inputText == "HELLO")
        #expect(appState.errorMessage == nil)
    }

    @Test func executeScriptFallsBackOnError() async throws {
        let scriptPath = try makeScript("exit 1")
        let script = Script(name: "Fail", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "original"

        await controller.executeScript(script)

        #expect(appState.inputText == "original")
        #expect(appState.errorMessage?.contains("Fail") == true)
        #expect(appState.errorMessage?.contains("exit 1") == true)
    }

    @Test func executeScriptFallsBackOnEmptyOutput() async throws {
        let scriptPath = try makeScript("printf ''")
        let script = Script(name: "Empty", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "original"

        await controller.executeScript(script)

        #expect(appState.inputText == "original")
        #expect(appState.errorMessage?.contains("Empty") == true)
        #expect(appState.errorMessage?.contains("empty output") == true)
    }

    @Test func executeScriptPassesContext() async throws {
        let scriptPath = try makeScript(
            "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END prompt=$KOECHO_PROMPT\""
        )
        let script = Script(name: "Context", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "input"
        appState.selectedText = "selected"
        appState.selectionStart = "10"
        appState.selectionEnd = "18"
        appState.promptText = "my prompt"

        await controller.executeScript(script)

        #expect(appState.inputText == "sel=selected start=10 end=18 prompt=my prompt")
    }

    @Test func executeScriptShowsPromptUI() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "original"

        await controller.executeScript(script)

        // First call with requiresPrompt sets promptScript but doesn't run
        #expect(appState.promptScript == script)
        #expect(appState.inputText == "original")
        #expect(appState.isRunningScript == false)
    }

    @Test func executeScriptWithPrompt() async throws {
        let scriptPath = try makeScript("echo \"prompt=$KOECHO_PROMPT\"")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "input"

        // First call: show prompt UI
        await controller.executeScript(script)
        #expect(appState.promptScript == script)

        // Simulate user entering prompt text
        appState.promptText = "user prompt"

        // Second call: execute with prompt
        await controller.executeScript(script)

        #expect(appState.inputText == "prompt=user prompt")
        #expect(appState.promptScript == nil)
        #expect(appState.promptText == "")
    }

    @Test func cancelPromptClearsState() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        await controller.executeScript(script)
        appState.promptText = "some text"

        #expect(appState.promptScript == script)

        controller.cancelPrompt()

        #expect(appState.promptScript == nil)
        #expect(appState.promptText == "")
    }

    @Test func executeScriptWhileRunningIsNoop() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Test", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "original"
        appState.isRunningScript = true

        await controller.executeScript(script)

        #expect(appState.inputText == "original")
    }

    @Test func executeScriptWhenNotVisibleIsNoop() async throws {
        let scriptPath = try makeScript("echo 'replaced'")
        let script = Script(name: "Test", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        // Don't call showPanel — panel is not visible
        appState.inputText = "original"

        await controller.executeScript(script)

        #expect(appState.inputText == "original")
    }

    @Test func clearStateClearsScriptState() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.isRunningScript = true
        appState.promptScript = Script(name: "Test", scriptPath: "/tmp/test.sh")
        appState.promptText = "prompt"

        controller.cancel()

        #expect(appState.isRunningScript == false)
        #expect(appState.promptScript == nil)
        #expect(appState.promptText == "")
    }

    @Test func confirmWhileRunningScriptIsNoop() async {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = NSRunningApplication.current
        appState.isRunningScript = true

        await controller.confirm()

        // confirm should be no-op, state unchanged
        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "hello")
    }

    @Test func escapeWhilePromptCancelsPromptOnly() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        await controller.executeScript(script)
        #expect(appState.promptScript == script)

        // Simulate Escape via onEscape callback
        controller.panel.onEscape?()

        // Prompt should be cancelled but panel stays visible
        #expect(appState.promptScript == nil)
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func executeScriptDuringPromptForDifferentScriptIsNoop() async throws {
        let scriptPath1 = try makeScript("cat")
        let scriptPath2 = try makeScript("echo 'other'")
        let script1 = Script(name: "Script1", scriptPath: scriptPath1, requiresPrompt: true)
        let script2 = Script(name: "Script2", scriptPath: scriptPath2)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "original"

        // Show prompt for script1
        await controller.executeScript(script1)
        #expect(appState.promptScript == script1)

        // Try to execute script2 while prompt is shown for script1
        await controller.executeScript(script2)

        // Should be no-op
        #expect(appState.inputText == "original")
        #expect(appState.promptScript == script1)
    }

    @Test func cancelDuringScriptDiscardsResult() async throws {
        let scriptPath = try makeScript("sleep 0.5 && echo done")
        let script = Script(name: "Slow", scriptPath: scriptPath)
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "original"

        let executeTask = Task { @MainActor in
            await controller.executeScript(script)
        }
        // Yield to let executeScript start
        await Task.yield()

        // Cancel while script is running
        controller.cancel()

        await executeTask.value

        // Result should be discarded because panel was cancelled
        #expect(appState.inputText == "")
        #expect(appState.isInputPanelVisible == false)
    }

    @Test func scriptErrorMessages() async throws {
        let (controller, appState, _) = makeController()
        controller.showPanel()

        // Test scriptNotFound
        let notFoundScript = Script(name: "Missing", scriptPath: "/nonexistent/script.sh")
        appState.inputText = "text"
        await controller.executeScript(notFoundScript)
        #expect(appState.errorMessage == "Script not found: /nonexistent/script.sh")

        // Test nonZeroExit with stderr
        let failPath = try makeScript("echo 'err msg' >&2; exit 2")
        let failScript = Script(name: "Fail", scriptPath: failPath)
        appState.errorMessage = nil
        appState.inputText = "text"
        await controller.executeScript(failScript)
        #expect(appState.errorMessage == "Script 'Fail' failed (exit 2): err msg")

        // Test emptyOutput
        let emptyPath = try makeScript("printf ''")
        let emptyScript = Script(name: "Empty", scriptPath: emptyPath)
        appState.errorMessage = nil
        appState.inputText = "text"
        await controller.executeScript(emptyScript)
        #expect(appState.errorMessage == "Script 'Empty' produced empty output.")

        // Test timeout
        let timeoutPath = try makeScript("sleep 10")
        let timeoutScript = Script(name: "Timeout", scriptPath: timeoutPath)
        let (controller2, appState2, _) = makeController(
            makeScriptRunner: { ScriptRunner(timeout: 0.1) }
        )
        controller2.showPanel()
        appState2.inputText = "text"
        await controller2.executeScript(timeoutScript)
        #expect(appState2.errorMessage == "Script 'Timeout' timed out.")
    }
}
