import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing
@testable import Koecho

@MainActor
private final class TestContext {
    let controller: InputPanelController
    let appState: AppState
    let paster: MockPaster
    let historyStore: HistoryStore
    let ducker: MockVolumeDucker

    init(
        controller: InputPanelController,
        appState: AppState,
        paster: MockPaster,
        historyStore: HistoryStore,
        ducker: MockVolumeDucker
    ) {
        self.controller = controller
        self.appState = appState
        self.paster = paster
        self.historyStore = historyStore
        self.ducker = ducker
    }

    isolated deinit {
        controller.panel.orderOut(nil)
    }
}

@MainActor
private func makeController(
    paster: MockPaster? = nil,
    selectedTextReader: (any SelectedTextReading)? = nil,
    makeScriptRunner: (() -> ScriptRunner)? = nil,
    ducker: MockVolumeDucker? = nil
) -> TestContext {
    let p = paster ?? MockPaster()
    let d = ducker ?? MockVolumeDucker()
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = Settings(defaults: defaults)
    let appState = AppState(settings: settings)
    let reader: any SelectedTextReading = selectedTextReader ?? SelectedTextReader()
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("koecho-test-\(UUID().uuidString)")
    let historyStore = HistoryStore(directoryURL: dir)
    let controller = InputPanelController(
        appState: appState,
        selectedTextReader: reader,
        paster: p,
        makeScriptRunner: makeScriptRunner ?? { ScriptRunner(timeout: appState.settings.script.scriptTimeout) },
        makeEngine: { MockVoiceInputEngine() },
        historyStore: historyStore,
        ducker: d
    )
    return TestContext(
        controller: controller,
        appState: appState,
        paster: p,
        historyStore: historyStore,
        ducker: d
    )
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
@Suite(.serialized)
struct InputPanelControllerTests {
    @Test func showPanelSetsState() {
        let ctx = makeController()

        ctx.controller.showPanel()

        #expect(ctx.appState.isInputPanelVisible == true)
        #expect(ctx.appState.inputText == "")
        #expect(ctx.controller.panel.isVisible)
    }

    @Test func cancelClearsState() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "some text"
        ctx.controller.cancel()

        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.appState.inputText == "")
        #expect(ctx.appState.frontmostApplication == nil)
        #expect(!ctx.controller.panel.isVisible)
    }

    @Test func closeButtonCancelsPanel() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "some text"
        ctx.controller.panel.close()

        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.appState.inputText == "")
    }

    @Test func cancelClearsTextAfterInput() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello world"
        ctx.controller.cancel()

        #expect(ctx.appState.inputText == "")
    }

    @Test func showPanelTwicePreservesText() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.controller.showPanel()

        #expect(ctx.appState.inputText == "hello")
        #expect(ctx.appState.isInputPanelVisible == true)
    }

    @Test func cancelWhenNotVisibleIsNoop() {
        let ctx = makeController()

        ctx.controller.cancel()

        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.appState.inputText == "")
    }

    @Test func showCancelShowCycle() {
        let ctx = makeController()

        ctx.controller.showPanel()
        #expect(ctx.appState.isInputPanelVisible == true)

        ctx.controller.cancel()
        #expect(ctx.appState.isInputPanelVisible == false)

        ctx.controller.showPanel()
        #expect(ctx.appState.isInputPanelVisible == true)
        #expect(ctx.appState.inputText == "")
        #expect(ctx.controller.panel.isVisible)
    }

    // MARK: - confirm tests

    @Test func confirmSuccessClearsState() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        // Set a fake frontmost app — use current app as a stand-in
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.appState.inputText == "")
        #expect(ctx.appState.frontmostApplication == nil)
        #expect(ctx.appState.errorMessage == nil)
        #expect(paster.pastedTexts == ["hello"])
    }

    @Test func confirmFailureShowsError() async {
        let paster = MockPaster()
        paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.appState.isInputPanelVisible == true)
        #expect(ctx.appState.inputText == "hello")
        #expect(ctx.appState.errorMessage != nil)
        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func confirmWithEmptyTextActsAsCancel() async {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "   \n  "

        await ctx.controller.confirm()

        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.appState.inputText == "")
        #expect(ctx.paster.restoreClipboardCallCount == 1)
    }

    @Test func confirmWhenNotVisibleIsNoop() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        await ctx.controller.confirm()

        #expect(paster.pastedTexts.isEmpty)
    }

    @Test func confirmWithNoTargetAppSetsError() async {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = nil

        await ctx.controller.confirm()

        #expect(ctx.appState.errorMessage == "No target application")
        #expect(ctx.appState.isInputPanelVisible == true)
    }

    @Test func cancelDuringConfirmIsIgnored() async throws {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        // Make paste suspend so we can call cancel() while confirm() is in progress
        paster.onPaste = {
            // Yield to allow cancel() to be attempted on the same actor
            await Task.yield()
        }

        // Start confirm in a Task so we can call cancel() after it begins
        let confirmTask = Task { @MainActor in
            await ctx.controller.confirm()
        }
        // Wait for confirmTask to progress past stopDictation() (100ms sleep)
        // and reach the onPaste suspension point
        try await Task.sleep(for: .milliseconds(200))

        // Panel should be hidden (confirm hides it before paste) but isConfirming is true
        // cancel() should be ignored because isConfirming is true
        ctx.controller.cancel()

        await confirmTask.value

        // Confirm should have succeeded — cancel was ignored
        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.appState.inputText == "")
        #expect(paster.pastedTexts == ["hello"])
    }

    @Test func cancelCallsRestoreClipboard() {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.controller.cancel()

        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func showPanelClearsErrorMessage() {
        let ctx = makeController()

        ctx.appState.errorMessage = "previous error"
        ctx.controller.showPanel()

        #expect(ctx.appState.errorMessage == nil)
    }

    // MARK: - executeScript tests

    @Test func executeScriptReplacesText() async throws {
        let scriptPath = try makeScript("tr a-z A-Z")
        let script = Script(name: "Upper", scriptPath: scriptPath)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"

        await ctx.controller.executeScript(script)

        #expect(ctx.appState.inputText == "HELLO")
        #expect(ctx.appState.errorMessage == nil)
    }

    @Test func executeScriptFallsBackOnError() async throws {
        let scriptPath = try makeScript("exit 1")
        let script = Script(name: "Fail", scriptPath: scriptPath)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        await ctx.controller.executeScript(script)

        #expect(ctx.appState.inputText == "original")
        #expect(ctx.appState.errorMessage?.contains("Fail") == true)
        #expect(ctx.appState.errorMessage?.contains("exit 1") == true)
    }

    @Test func executeScriptFallsBackOnEmptyOutput() async throws {
        let scriptPath = try makeScript("printf ''")
        let script = Script(name: "Empty", scriptPath: scriptPath)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        await ctx.controller.executeScript(script)

        #expect(ctx.appState.inputText == "original")
        #expect(ctx.appState.errorMessage?.contains("Empty") == true)
        #expect(ctx.appState.errorMessage?.contains("empty output") == true)
    }

    @Test func executeScriptPassesContext() async throws {
        let scriptPath = try makeScript(
            "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END prompt=$KOECHO_PROMPT\""
        )
        let script = Script(name: "Context", scriptPath: scriptPath)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "input"
        ctx.appState.promptText = "my prompt"

        await ctx.controller.executeScript(script)

        // Selection comes from textView (no text selected in mock), so selection is empty
        #expect(ctx.appState.inputText == "sel= start=0 end=0 prompt=my prompt")
    }

    @Test func executeScriptShowsPromptUI() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        await ctx.controller.executeScript(script)

        // First call with requiresPrompt sets promptScript but doesn't run
        #expect(ctx.appState.promptScript == script)
        #expect(ctx.appState.inputText == "original")
        #expect(ctx.appState.isRunningScript == false)
    }

    @Test func executeScriptWithPrompt() async throws {
        let scriptPath = try makeScript("echo \"prompt=$KOECHO_PROMPT\"")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "input"

        // First call: show prompt UI
        await ctx.controller.executeScript(script)
        #expect(ctx.appState.promptScript == script)

        // Simulate user entering prompt text
        ctx.appState.promptText = "user prompt"

        // Second call: execute with prompt
        await ctx.controller.executeScript(script)

        #expect(ctx.appState.inputText == "prompt=user prompt")
        #expect(ctx.appState.promptScript == nil)
        #expect(ctx.appState.promptText == "")
    }

    @Test func cancelPromptClearsState() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let ctx = makeController()

        ctx.controller.showPanel()
        await ctx.controller.executeScript(script)
        ctx.appState.promptText = "some text"

        #expect(ctx.appState.promptScript == script)

        ctx.controller.cancelPrompt()

        #expect(ctx.appState.promptScript == nil)
        #expect(ctx.appState.promptText == "")
    }

    @Test func executeScriptWhileRunningIsNoop() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Test", scriptPath: scriptPath)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"
        ctx.appState.isRunningScript = true

        await ctx.controller.executeScript(script)

        #expect(ctx.appState.inputText == "original")
    }

    @Test func executeScriptWhenNotVisibleIsNoop() async throws {
        let scriptPath = try makeScript("echo 'replaced'")
        let script = Script(name: "Test", scriptPath: scriptPath)
        let ctx = makeController()

        // Don't call showPanel — panel is not visible
        ctx.appState.inputText = "original"

        await ctx.controller.executeScript(script)

        #expect(ctx.appState.inputText == "original")
    }

    @Test func clearStateClearsScriptState() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.isRunningScript = true
        ctx.appState.promptScript = Script(name: "Test", scriptPath: "/tmp/test.sh")
        ctx.appState.promptText = "prompt"

        ctx.controller.cancel()

        #expect(ctx.appState.isRunningScript == false)
        #expect(ctx.appState.promptScript == nil)
        #expect(ctx.appState.promptText == "")
    }

    @Test func confirmWhileRunningScriptIsNoop() async {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current
        ctx.appState.isRunningScript = true

        await ctx.controller.confirm()

        // confirm should be no-op, state unchanged
        #expect(ctx.appState.isInputPanelVisible == true)
        #expect(ctx.appState.inputText == "hello")
    }

    @Test func escapeWhilePromptCancelsPromptOnly() async throws {
        let scriptPath = try makeScript("cat")
        let script = Script(name: "Prompt", scriptPath: scriptPath, requiresPrompt: true)
        let ctx = makeController()

        ctx.controller.showPanel()
        await ctx.controller.executeScript(script)
        #expect(ctx.appState.promptScript == script)

        // Simulate Escape via onEscape callback
        ctx.controller.panel.onEscape?()

        // Prompt should be cancelled but panel stays visible
        #expect(ctx.appState.promptScript == nil)
        #expect(ctx.appState.isInputPanelVisible == true)
    }

    @Test func executeScriptDuringPromptForDifferentScriptIsNoop() async throws {
        let scriptPath1 = try makeScript("cat")
        let scriptPath2 = try makeScript("echo 'other'")
        let script1 = Script(name: "Script1", scriptPath: scriptPath1, requiresPrompt: true)
        let script2 = Script(name: "Script2", scriptPath: scriptPath2)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        // Show prompt for script1
        await ctx.controller.executeScript(script1)
        #expect(ctx.appState.promptScript == script1)

        // Try to execute script2 while prompt is shown for script1
        await ctx.controller.executeScript(script2)

        // Should be no-op
        #expect(ctx.appState.inputText == "original")
        #expect(ctx.appState.promptScript == script1)
    }

    @Test func cancelDuringScriptDiscardsResult() async throws {
        let scriptPath = try makeScript("sleep 0.5 && echo done")
        let script = Script(name: "Slow", scriptPath: scriptPath)
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        let executeTask = Task { @MainActor in
            await ctx.controller.executeScript(script)
        }
        // Yield to let executeScript start
        await Task.yield()

        // Cancel while script is running
        ctx.controller.cancel()

        await executeTask.value

        // Result should be discarded because panel was cancelled
        #expect(ctx.appState.inputText == "")
        #expect(ctx.appState.isInputPanelVisible == false)
    }

    // MARK: - Replacement Rules on Confirm

    @Test func confirmAppliesReplacementRules() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello world"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(paster.pastedTexts == ["bye world"])
    }

    @Test func confirmWithReplacementRulesEmptyingText() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: ".*", replacement: "", usesRegularExpression: true)
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        // All text removed by replacement → treated as cancel
        #expect(paster.pastedTexts.isEmpty)
        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func scriptErrorMessages() async throws {
        let ctx = makeController()
        ctx.controller.showPanel()

        // Test emptyScript
        let emptyScriptEntry = Script(name: "Empty", scriptPath: "")
        ctx.appState.inputText = "text"
        await ctx.controller.executeScript(emptyScriptEntry)
        #expect(ctx.appState.errorMessage == "Script command is empty.")

        // Test nonZeroExit with stderr
        let failPath = try makeScript("echo 'err msg' >&2; exit 2")
        let failScript = Script(name: "Fail", scriptPath: failPath)
        ctx.appState.errorMessage = nil
        ctx.appState.inputText = "text"
        await ctx.controller.executeScript(failScript)
        #expect(ctx.appState.errorMessage == "Script 'Fail' failed (exit 2): err msg")

        // Test emptyOutput
        let emptyPath = try makeScript("printf ''")
        let emptyScript = Script(name: "Empty", scriptPath: emptyPath)
        ctx.appState.errorMessage = nil
        ctx.appState.inputText = "text"
        await ctx.controller.executeScript(emptyScript)
        #expect(ctx.appState.errorMessage == "Script 'Empty' produced empty output.")

        // Test timeout
        let timeoutPath = try makeScript("sleep 10")
        let timeoutScript = Script(name: "Timeout", scriptPath: timeoutPath)
        let ctx2 = makeController(
            makeScriptRunner: { ScriptRunner(timeout: 0.1) }
        )
        ctx2.controller.showPanel()
        ctx2.appState.inputText = "text"
        await ctx2.controller.executeScript(timeoutScript)
        #expect(ctx2.appState.errorMessage == "Script 'Timeout' timed out.")
    }

    // MARK: - Manual Replacement Rules

    @Test func applyReplacementRulesNowReplacesText() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと天気"

        ctx.controller.applyReplacementRulesNow()

        #expect(ctx.appState.inputText == "天気")
    }

    @Test func applyReplacementRulesNowWhenNotVisibleIsNoop() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        // Don't call showPanel — panel is not visible
        ctx.appState.inputText = "えーと天気"

        ctx.controller.applyReplacementRulesNow()

        #expect(ctx.appState.inputText == "えーと天気")
    }

    @Test func applyReplacementRulesNowDuringScriptIsNoop() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと天気"
        ctx.appState.isRunningScript = true

        ctx.controller.applyReplacementRulesNow()

        #expect(ctx.appState.inputText == "えーと天気")
    }

    @Test func applyReplacementRulesNowWithNoRulesIsNoop() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"

        ctx.controller.applyReplacementRulesNow()

        #expect(ctx.appState.inputText == "hello")
    }

    @Test func applyReplacementRulesNowWithNoMatchIsNoop() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"

        ctx.controller.applyReplacementRulesNow()

        #expect(ctx.appState.inputText == "hello")
    }

    @Test func shortcutRAppliesReplacementRules() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと天気"

        let handled = ctx.controller.panel.onShortcutKey?(ShortcutKey(modifiers: [.control], character: "r"))

        #expect(handled == true)
        #expect(ctx.appState.inputText == "天気")
    }

    @Test func shortcutRFallsBackToScriptWhenNoRules() async throws {
        let scriptPath = try makeScript("echo 'script output'")
        let ctrlR = ShortcutKey(modifiers: [.control], character: "r")
        let script = Script(name: "R Script", scriptPath: scriptPath, shortcutKey: ctrlR)
        let ctx = makeController()
        ctx.appState.settings.script.scripts = [script]
        // No replacement rules — Ctrl+R should fall through to script

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        let handled = ctx.controller.panel.onShortcutKey?(ctrlR)

        #expect(handled == true)
        // Let the script Task execute
        await Task.yield()
        try await Task.sleep(for: .milliseconds(500))
        #expect(ctx.appState.inputText == "script output")
    }

    @Test func shortcutRTakesPriorityOverScript() async throws {
        let scriptPath = try makeScript("echo 'script output'")
        let ctrlR = ShortcutKey(modifiers: [.control], character: "r")
        let script = Script(name: "R Script", scriptPath: scriptPath, shortcutKey: ctrlR)
        let ctx = makeController()
        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと天気"

        let handled = ctx.controller.panel.onShortcutKey?(ctrlR)

        #expect(handled == true)
        // Text should be replaced by replacement rules, not by script
        #expect(ctx.appState.inputText == "天気")
    }

    @Test func customShortcutKeyAppliesReplacementRules() {
        let ctx = makeController()
        ctx.appState.settings.replacement.replacementShortcutKey = ShortcutKey(modifiers: [.control], character: "x")
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと天気"

        // Ctrl+X should apply replacement rules
        let handledX = ctx.controller.panel.onShortcutKey?(ShortcutKey(modifiers: [.control], character: "x"))
        #expect(handledX == true)
        #expect(ctx.appState.inputText == "天気")

        // Ctrl+R should NOT apply replacement rules (no longer the shortcut)
        ctx.appState.inputText = "えーと天気"
        let handledR = ctx.controller.panel.onShortcutKey?(ShortcutKey(modifiers: [.control], character: "r"))
        #expect(handledR == false)
    }

    @Test func nilShortcutKeyDisablesShortcut() async throws {
        let scriptPath = try makeScript("echo 'script output'")
        let ctrlR = ShortcutKey(modifiers: [.control], character: "r")
        let script = Script(name: "R Script", scriptPath: scriptPath, shortcutKey: ctrlR)
        let ctx = makeController()
        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.replacement.replacementShortcutKey = nil
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと天気"

        // Ctrl+R should fall through to script (replacement shortcut is nil)
        let handled = ctx.controller.panel.onShortcutKey?(ctrlR)
        #expect(handled == true)
        await Task.yield()
        try await Task.sleep(for: .milliseconds(500))
        #expect(ctx.appState.inputText == "script output")
    }

    @Test func cmdShiftShortcutExecutesScript() async throws {
        let scriptPath = try makeScript("echo 'cmd-shift output'")
        let cmdShiftC = ShortcutKey(modifiers: [.command, .shift], character: "c")
        let script = Script(name: "CmdShift", scriptPath: scriptPath, shortcutKey: cmdShiftC)
        let ctx = makeController()
        ctx.appState.settings.script.scripts = [script]

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        let handled = ctx.controller.panel.onShortcutKey?(cmdShiftC)

        #expect(handled == true)
        await Task.yield()
        try await Task.sleep(for: .milliseconds(500))
        #expect(ctx.appState.inputText == "cmd-shift output")
    }

    @Test func modifierMismatchDoesNotExecuteScript() {
        let cmdC = ShortcutKey(modifiers: [.command], character: "c")
        let cmdShiftC = ShortcutKey(modifiers: [.command, .shift], character: "c")
        let script = Script(name: "CmdC", scriptPath: "/bin/echo", shortcutKey: cmdC)
        let ctx = makeController()
        ctx.appState.settings.script.scripts = [script]

        ctx.controller.showPanel()
        ctx.appState.inputText = "original"

        // Cmd+Shift+C should NOT match Cmd+C
        let handled = ctx.controller.panel.onShortcutKey?(cmdShiftC)
        #expect(handled == false)
        #expect(ctx.appState.inputText == "original")
    }

    // MARK: - History

    @Test func confirmRecordsHistory() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.historyStore.entries.count == 1)
        #expect(ctx.historyStore.entries[0].text == "hello")
    }

    @Test func confirmRecordsTextAfterReplacement() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "えーと今日はいい天気"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.historyStore.entries.count == 1)
        #expect(ctx.historyStore.entries[0].text == "今日はいい天気")
    }

    @Test func confirmDoesNotRecordWhenDisabled() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.history.isHistoryEnabled = false

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.historyStore.entries.isEmpty)
    }

    @Test func confirmDoesNotRecordOnPasteFailure() async {
        let paster = MockPaster()
        paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.historyStore.entries.isEmpty)
    }

    @Test func confirmDoesNotRecordEmptyText() async {
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.controller.showPanel()
        ctx.appState.inputText = "   \n  "
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.historyStore.entries.isEmpty)
    }

    // MARK: - Add Replacement Rule from Context Menu

    @Test func addReplacementRuleSavesAndApplies() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello world hello"

        let rule = ReplacementRule(pattern: "hello", replacement: "hi")
        ctx.controller.addReplacementRule(rule)

        #expect(ctx.appState.settings.replacement.replacementRules.count == 1)
        #expect(ctx.appState.settings.replacement.replacementRules[0].pattern == "hello")
        #expect(ctx.appState.settings.replacement.replacementRules[0].replacement == "hi")
        #expect(ctx.appState.inputText == "hi world hi")
        #expect(ctx.appState.pendingReplacementPattern == nil)
    }

    @Test func cancelClearsPendingReplacementPattern() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.appState.pendingReplacementPattern = "test"

        ctx.controller.cancel()

        #expect(ctx.appState.pendingReplacementPattern == nil)
    }

    @Test func addReplacementRuleAppliesAllRules() {
        let ctx = makeController()

        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "world", replacement: "earth")
        )

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello world"

        let newRule = ReplacementRule(pattern: "hello", replacement: "hi")
        ctx.controller.addReplacementRule(newRule)

        // Both existing and new rules should be applied
        #expect(ctx.appState.settings.replacement.replacementRules.count == 2)
        #expect(ctx.appState.inputText == "hi earth")
    }

    // MARK: - Panel Configuration

    @Test func panelHasResizeConstraints() {
        let ctx = makeController()
        #expect(ctx.controller.panel.contentMinSize == NSSize(width: 200, height: 150))
        #expect(ctx.controller.panel.frameAutosaveName == "InputPanel")
    }

    // MARK: - Selected Text as Initial Input

    @Test func showPanelWithSelectedTextSetsInputText() {
        let mockReader = MockSelectedTextReader()
        mockReader.resultToReturn = SelectedTextResult(text: "selected text")
        let ctx = makeController(selectedTextReader: mockReader)

        ctx.controller.showPanel()

        #expect(ctx.appState.inputText == "selected text")
    }

    @Test func confirmWithSelectedTextOnly() async {
        let mockReader = MockSelectedTextReader()
        mockReader.resultToReturn = SelectedTextResult(text: "selected text")
        let paster = MockPaster()
        let ctx = makeController(paster: paster, selectedTextReader: mockReader)

        ctx.controller.showPanel()
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(paster.pastedTexts == ["selected text"])
        #expect(ctx.appState.isInputPanelVisible == false)
    }

    // MARK: - Auto Replacement

    @Test func autoReplacementTriggersImmediately() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.controller.handleTextChanged("えーと天気")

        // Replacement is applied immediately on text change
        #expect(ctx.appState.inputText == "天気")
    }

    @Test func autoReplacementDisabledDoesNotTrigger() {
        let ctx = makeController()
        ctx.appState.settings.replacement.isAutoReplacementEnabled = false
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.controller.handleTextChanged("えーと天気")

        #expect(ctx.appState.inputText == "えーと天気")
    }

    @Test func autoReplacementAppliesMultipleInputs() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        ctx.controller.showPanel()
        ctx.controller.handleTextChanged("えーと天気")
        #expect(ctx.appState.inputText == "天気")

        ctx.controller.handleTextChanged("えーとこんにちは")
        #expect(ctx.appState.inputText == "こんにちは")
    }

    @Test func autoReplacementSkipsWhenNoRules() {
        let ctx = makeController()

        ctx.controller.showPanel()
        ctx.controller.handleTextChanged("hello world")

        #expect(ctx.appState.inputText == "hello world")
    }

    @Test func autoReplacementSkipsWhenNotVisible() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )

        // Don't call showPanel
        ctx.controller.handleTextChanged("hello world")

        #expect(ctx.appState.inputText == "hello world")
    }

    @Test func autoReplacementSkipsDuringScriptExecution() {
        let ctx = makeController()
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )

        ctx.controller.showPanel()
        ctx.appState.isRunningScript = true
        ctx.controller.handleTextChanged("hello world")

        #expect(ctx.appState.inputText == "hello world")
    }

    // MARK: - Auto-Run Script

    @Test func cycleAutoRunScript() {
        let ctx = makeController()
        let script0 = Script(name: "A", scriptPath: "/bin/echo")
        let script1 = Script(name: "B", scriptPath: "/bin/echo")
        let promptScript = Script(name: "P", scriptPath: "/bin/echo", requiresPrompt: true)
        ctx.appState.settings.script.scripts = [script0, promptScript, script1]

        // nil → script0
        ctx.controller.cycleAutoRunScript()
        #expect(ctx.appState.settings.script.autoRunScriptId == script0.id)

        // script0 → script1
        ctx.controller.cycleAutoRunScript()
        #expect(ctx.appState.settings.script.autoRunScriptId == script1.id)

        // script1 → nil
        ctx.controller.cycleAutoRunScript()
        #expect(ctx.appState.settings.script.autoRunScriptId == nil)
    }

    @Test func cycleAutoRunScriptNoEligible() {
        let ctx = makeController()
        let promptScript = Script(name: "P", scriptPath: "/bin/echo", requiresPrompt: true)
        ctx.appState.settings.script.scripts = [promptScript]

        ctx.controller.cycleAutoRunScript()
        #expect(ctx.appState.settings.script.autoRunScriptId == nil)
    }

    @Test func confirmWithAutoRunScript() async throws {
        let scriptPath = try makeScript("tr a-z A-Z")
        let script = Script(name: "Upper", scriptPath: scriptPath)
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.script.autoRunScriptId = script.id

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(paster.pastedTexts == ["HELLO"])
        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(ctx.historyStore.entries.count == 1)
        #expect(ctx.historyStore.entries[0].text == "HELLO")
    }

    @Test func confirmAutoRunScriptError() async throws {
        let scriptPath = try makeScript("exit 1")
        let script = Script(name: "Fail", scriptPath: scriptPath)
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.script.autoRunScriptId = script.id

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.appState.isInputPanelVisible == true)
        #expect(ctx.appState.errorMessage != nil)
        #expect(paster.pastedTexts.isEmpty)
        #expect(ctx.appState.inputText == "hello")
    }

    @Test func confirmAutoRunScriptEmptyOutput() async throws {
        let scriptPath = try makeScript("printf ''")
        let script = Script(name: "Empty", scriptPath: scriptPath)
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.script.autoRunScriptId = script.id

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        await ctx.controller.confirm()

        #expect(ctx.appState.isInputPanelVisible == true)
        #expect(ctx.appState.errorMessage?.contains("empty output") == true)
        #expect(paster.pastedTexts.isEmpty)
        #expect(ctx.appState.inputText == "hello")
    }

    @Test func deleteScriptClearsAutoRun() {
        let ctx = makeController()
        let script = Script(name: "Test", scriptPath: "/bin/echo")
        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.script.autoRunScriptId = script.id

        ctx.appState.settings.script.deleteScript(id: script.id)

        #expect(ctx.appState.settings.script.autoRunScriptId == nil)
    }

    @Test func cancelDuringAutoRun() async throws {
        let scriptPath = try makeScript("sleep 0.5 && echo done")
        let script = Script(name: "Slow", scriptPath: scriptPath)
        let paster = MockPaster()
        let ctx = makeController(paster: paster)

        ctx.appState.settings.script.scripts = [script]
        ctx.appState.settings.script.autoRunScriptId = script.id

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"
        ctx.appState.frontmostApplication = NSRunningApplication.current

        let confirmTask = Task { @MainActor in
            await ctx.controller.confirm()
        }
        await Task.yield()

        ctx.controller.cancel()

        await confirmTask.value

        #expect(ctx.appState.isInputPanelVisible == false)
        #expect(paster.pastedTexts.isEmpty)
    }

    @Test func autoRunShortcutPriority() {
        let ctx = makeController()
        let ctrlA = ShortcutKey(modifiers: [.control], character: "a")
        ctx.appState.settings.script.autoRunShortcutKey = ctrlA
        ctx.appState.settings.replacement.replacementShortcutKey = ctrlA
        ctx.appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )
        let script = Script(name: "A", scriptPath: "/bin/echo")
        ctx.appState.settings.script.scripts = [script]

        ctx.controller.showPanel()
        ctx.appState.inputText = "hello"

        let handled = ctx.controller.panel.onShortcutKey?(ctrlA)

        #expect(handled == true)
        // Auto-run cycle should have been triggered, not replacement
        #expect(ctx.appState.settings.script.autoRunScriptId == script.id)
        // Text should NOT have been replaced by replacement rules
        #expect(ctx.appState.inputText == "hello")
    }

    // MARK: - Volume Ducking

    @Test func showPanelCallsDuck() {
        let ducker = MockVolumeDucker()
        let ctx = makeController(ducker: ducker)
        ctx.controller.showPanel()
        #expect(ducker.duckCallCount == 1)
    }

    @Test func cancelCallsRestore() {
        let ducker = MockVolumeDucker()
        let ctx = makeController(ducker: ducker)
        ctx.controller.showPanel()
        ctx.controller.cancel()
        #expect(ducker.restoreCallCount == 1)
    }

    @Test func showPanelTwiceDoesNotDoubleDuck() {
        let ducker = MockVolumeDucker()
        let ctx = makeController(ducker: ducker)
        ctx.controller.showPanel()
        ctx.controller.showPanel()
        #expect(ducker.duckCallCount == 1)
    }

    @Test func confirmEmptyTextCallsRestore() async {
        let ducker = MockVolumeDucker()
        let ctx = makeController(ducker: ducker)
        ctx.controller.showPanel()
        ctx.appState.inputText = ""
        await ctx.controller.confirm()
        // Empty text path calls clearState() which calls restore()
        #expect(ducker.restoreCallCount == 1)
    }

    // MARK: - SpeechAnalyzer Overlap Removal

    @Test func overlapRemovalFullDuplicate() {
        let ctx = makeController()
        ctx.controller.showPanel()

        // Simulate first finalize: "なんですか？"
        ctx.controller.voiceInput(didFinalize: "なんですか？")
        let firstText = ctx.appState.inputText

        // Simulate second finalize with overlap: "なんですか？こんにちは。"
        ctx.controller.voiceInput(didFinalize: "なんですか？こんにちは。")

        // Only "こんにちは。" should be added
        #expect(ctx.appState.inputText == firstText + "こんにちは。")
    }

    @Test func overlapRemovalPartialPunctuation() {
        let ctx = makeController()
        ctx.controller.showPanel()

        // Simulate finalize ending with punctuation
        ctx.controller.voiceInput(didFinalize: "hello.")

        // Next finalize starts with the same punctuation
        ctx.controller.voiceInput(didFinalize: ".world")

        // The overlapping "." should be removed
        #expect(ctx.appState.inputText == "hello.world")
    }

    @Test func overlapRemovalNoOverlap() {
        let ctx = makeController()
        ctx.controller.showPanel()

        ctx.controller.voiceInput(didFinalize: "hello")
        ctx.controller.voiceInput(didFinalize: " world")

        #expect(ctx.appState.inputText == "hello world")
    }

    @Test func overlapRemovalCompleteDuplicate() {
        let ctx = makeController()
        ctx.controller.showPanel()

        ctx.controller.voiceInput(didFinalize: "hello")
        // Complete duplicate — should produce empty after stripping
        ctx.controller.voiceInput(didFinalize: "hello")

        #expect(ctx.appState.inputText == "hello")
    }

    @Test func overlapRemovalSingleNonPunctuationNotStripped() {
        let ctx = makeController()
        ctx.controller.showPanel()

        ctx.controller.voiceInput(didFinalize: "あ")
        // Single char non-punctuation overlap should NOT be stripped
        ctx.controller.voiceInput(didFinalize: "あいう")

        #expect(ctx.appState.inputText == "ああいう")
    }

    @Test func overlapRemovalResetOnShowPanel() {
        let ctx = makeController()
        ctx.controller.showPanel()
        ctx.controller.voiceInput(didFinalize: "hello")

        // Cancel and reopen
        ctx.controller.cancel()
        ctx.controller.showPanel()

        // After reopen, accumulated should be reset — no stripping
        ctx.controller.voiceInput(didFinalize: "hello")
        #expect(ctx.appState.inputText == "hello")
    }

    @Test func overlapRemovalResetOnSwitchEngine() async {
        let ctx = makeController()
        ctx.controller.showPanel()
        ctx.controller.voiceInput(didFinalize: "hello")

        await ctx.controller.switchEngine()

        // After switch, accumulated should be reset — no stripping
        ctx.controller.voiceInput(didFinalize: "hello")

        // inputText should contain "hello" from after switch (first "hello" was cleared by switchEngine reading textView)
        #expect(ctx.appState.inputText.contains("hello"))
    }

    // MARK: - Replay Volatile Suppression

    private func findTextView(in controller: InputPanelController) -> VoiceInputTextView? {
        func find(in view: NSView) -> VoiceInputTextView? {
            if let tv = view as? VoiceInputTextView { return tv }
            for sub in view.subviews {
                if let found = find(in: sub) { return found }
            }
            return nil
        }
        return controller.panel.contentView.flatMap { find(in: $0) }
    }

    /// Simulate local finalization: set volatile text, finalize it, trigger onVolatileFinalized.
    private func simulateLocalFinalize(
        controller: InputPanelController,
        textView: VoiceInputTextView,
        text: String
    ) {
        controller.voiceInput(didUpdateVolatile: text)
        textView.finalizeVolatileText()
        textView.onVolatileFinalized?(text)
    }

    @Test func replayVolatileSuppressedDuringTimeWindow() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        ctx.controller.replaySuppressionDeadline = Date.now + 10
        let textAfterFinalize = ctx.appState.inputText

        // Replay volatile "こん" — should be suppressed during time window
        ctx.controller.voiceInput(didUpdateVolatile: "こん")
        #expect(textView.volatileRange == nil)
        #expect(ctx.appState.inputText == textAfterFinalize)
    }

    @Test func volatileDisplayedAfterDeadlineExpires() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        // Set deadline in the past — expired
        ctx.controller.replaySuppressionDeadline = Date.now - 1

        // New volatile after deadline expired — should be displayed
        ctx.controller.voiceInput(didUpdateVolatile: "あ")
        #expect(textView.volatileRange != nil)
        // Flags should be cleared
        #expect(ctx.controller.isLocallyFinalized == false)
    }

    @Test func replayFinalizeSkippedByExactMatch() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        // Insert text via normal finalize first
        ctx.controller.voiceInput(didFinalize: "こんにちは")
        let textAfterFirstFinalize = ctx.appState.inputText

        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        ctx.controller.replaySuppressionDeadline = Date.now + 10

        // Replay finalize — exact match with localFinalizedText → skipped
        ctx.controller.voiceInput(didFinalize: "こんにちは")
        #expect(ctx.appState.inputText == textAfterFirstFinalize)
        #expect(ctx.controller.isLocallyFinalized == false)
        #expect(ctx.controller.replaySuppressionDeadline == nil)
    }

    @Test func replayFinalizeClearsDeadline() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        // Insert text via normal finalize first
        ctx.controller.voiceInput(didFinalize: "こんにちは")

        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        ctx.controller.replaySuppressionDeadline = Date.now + 10

        // Replay finalize — clears deadline
        ctx.controller.voiceInput(didFinalize: "こんにちは")
        #expect(ctx.controller.replaySuppressionDeadline == nil)

        // Next volatile should be displayed (deadline cleared)
        ctx.controller.voiceInput(didUpdateVolatile: "あ")
        #expect(textView.volatileRange != nil)
    }

    @Test func newFinalizeWhileLocallyFinalizedInsertsText() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        // Insert text via normal finalize first
        ctx.controller.voiceInput(didFinalize: "こんにちは")

        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        ctx.controller.replaySuppressionDeadline = Date.now + 10

        // New speech finalize with no overlap — should be inserted
        ctx.controller.voiceInput(didFinalize: "ありがとう")
        #expect(ctx.appState.inputText.contains("ありがとう"))
        #expect(ctx.controller.isLocallyFinalized == false)
    }

    @Test func newInputAfterReplay() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        // Insert text via normal finalize first
        ctx.controller.voiceInput(didFinalize: "こんにちは")

        // Local finalize (e.g. user presses Enter)
        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        ctx.controller.replaySuppressionDeadline = Date.now + 10

        // Replay finalize — clears flags
        ctx.controller.voiceInput(didFinalize: "こんにちは")

        // New volatile should now be displayed
        ctx.controller.voiceInput(didUpdateVolatile: "あ")
        #expect(textView.volatileRange != nil)

        // New finalize should insert text
        let textBeforeFinalize = ctx.appState.inputText
        ctx.controller.voiceInput(didFinalize: "ありがとう")
        #expect(ctx.appState.inputText != textBeforeFinalize)
        #expect(ctx.appState.inputText.contains("ありがとう"))
    }

    @Test func sameTextReSpokenAfterReplay() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        // Insert text via normal finalize first so accumulatedFinalizedText is set
        ctx.controller.voiceInput(didFinalize: "こんにちは")
        let textAfterFirstFinalize = ctx.appState.inputText

        // Now simulate local finalize (as if user typed Enter to restart transcriber)
        simulateLocalFinalize(controller: ctx.controller, textView: textView, text: "こんにちは")
        ctx.controller.replaySuppressionDeadline = Date.now + 10

        // Replay finalize — clears flags
        ctx.controller.voiceInput(didFinalize: "こんにちは")

        // Same text finalized again — stripOverlappingPrefix removes it
        ctx.controller.voiceInput(didFinalize: "こんにちは")
        #expect(ctx.appState.inputText == textAfterFirstFinalize)
    }

    @Test func volatileDisplayedWithoutDeadline() {
        let ctx = makeController()
        ctx.controller.showPanel()
        guard let textView = findTextView(in: ctx.controller) else {
            Issue.record("textView not found")
            return
        }

        // No simulateLocalFinalize, no deadline — initial state
        ctx.controller.voiceInput(didUpdateVolatile: "あ")
        #expect(textView.volatileRange != nil)
    }
}
