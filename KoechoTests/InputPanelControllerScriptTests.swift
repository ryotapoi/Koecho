import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// MARK: - executeScript

extension InputPanelControllerTests {
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

  @Test func scriptErrorMessages() async throws {
    let ctx = makeController()
    ctx.controller.showPanel()

    // Test emptyScript
    let emptyScriptEntry = Script(name: "Empty", scriptPath: "")
    ctx.appState.inputText = "text"
    await ctx.controller.executeScript(emptyScriptEntry)
    #expect(ctx.appState.errorMessage == String(localized: "Script command is empty."))

    // Test nonZeroExit with stderr
    let failPath = try makeScript("echo 'err msg' >&2; exit 2")
    let failScript = Script(name: "Fail", scriptPath: failPath)
    ctx.appState.errorMessage = nil
    ctx.appState.inputText = "text"
    await ctx.controller.executeScript(failScript)
    #expect(ctx.appState.errorMessage?.contains("Fail") == true)
    #expect(ctx.appState.errorMessage?.contains("err msg") == true)

    // Test emptyOutput
    let emptyPath = try makeScript("printf ''")
    let emptyScript = Script(name: "Empty", scriptPath: emptyPath)
    ctx.appState.errorMessage = nil
    ctx.appState.inputText = "text"
    await ctx.controller.executeScript(emptyScript)
    #expect(ctx.appState.errorMessage?.contains("Empty") == true)

    // Test timeout
    let timeoutPath = try makeScript("sleep 10")
    let timeoutScript = Script(name: "Timeout", scriptPath: timeoutPath)
    let ctx2 = makeController(
      makeScriptRunner: { ScriptRunner(timeout: 0.1) }
    )
    ctx2.controller.showPanel()
    ctx2.appState.inputText = "text"
    await ctx2.controller.executeScript(timeoutScript)
    #expect(ctx2.appState.errorMessage?.contains("Timeout") == true)
  }

  // MARK: - Script shortcuts

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
    await ctx.controller.shortcutScriptTask?.value
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
    #expect(ctx.appState.errorMessage?.contains("Empty") == true)
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
}
