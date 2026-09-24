import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// MARK: - Script controller connections

extension InputPanelControllerTests {
  @Test func clearStateClearsScriptState() {
    let ctx = makeController()

    ctx.controller.showPanel()
    ctx.appState.isRunningScript = true
    ctx.appState.promptScript = Script(name: "Test", scriptPath: "/tmp/test.sh")
    ctx.appState.promptText = "prompt"
    ctx.appState.offerScriptUndo(restoring: "before")

    ctx.controller.cancel()

    #expect(ctx.appState.isRunningScript == false)
    #expect(ctx.appState.promptScript == nil)
    #expect(ctx.appState.promptText == "")
    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func confirmedTextEditInvalidatesScriptUndo() {
    let ctx = makeController()
    ctx.controller.showPanel()
    ctx.appState.setInputText("after")
    ctx.appState.offerScriptUndo(restoring: "before")

    ctx.controller.handleTextChanged("edited")

    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func markedTextEditInvalidatesScriptUndo() async throws {
    let ctx = makeController()
    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    ctx.appState.setInputText("after")
    textView.replaceText("after")
    ctx.appState.offerScriptUndo(restoring: "before")

    textView.setMarkedText(
      "あ",
      selectedRange: NSRange(location: 1, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: 0)
    )

    #expect(textView.hasMarkedText())
    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func showPanelDiscardsPreviousScriptUndo() {
    let ctx = makeController()
    ctx.appState.offerScriptUndo(restoring: "before")

    ctx.controller.showPanel()

    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func confirmWhileRunningScriptIsNoop() async {
    let ctx = makeController()

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current
    ctx.appState.isRunningScript = true

    await ctx.controller.confirm()

    // confirm should be no-op, state unchanged
    #expect(ctx.appState.isInputPanelVisible == true)
    #expect(ctx.appState.inputText == "hello")
  }

  @Test func escapeWhilePromptCancelsPromptOnly() async throws {
    let shortcut = ShortcutKey(modifiers: [.control], character: "p")
    let script = Script(name: "Prompt", scriptPath: "cat", shortcutKey: shortcut, requiresPrompt: true)
    let ctx = makeController()
    ctx.appState.settings.script.scripts = [script]

    ctx.controller.showPanel()
    #expect(ctx.controller.panel.onShortcutKey?(shortcut) == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.promptScript == script)
    ctx.appState.promptText = "prompt"
    ctx.appState.volatilePromptText = "volatile"
    ctx.controller.voiceCoordinator.currentVoiceTarget = .prompt

    // Simulate Escape via onEscape callback
    ctx.controller.panel.onEscape?()

    // Prompt should be cancelled but panel stays visible
    #expect(ctx.appState.promptScript == nil)
    #expect(ctx.appState.promptText == "")
    #expect(ctx.appState.volatilePromptText == "")
    #expect(ctx.controller.voiceCoordinator.currentVoiceTarget == .textEditor)
    #expect(ctx.appState.isInputPanelVisible == true)
  }

  @Test func cancelDuringScriptDiscardsResult() async throws {
    let shortcut = ShortcutKey(modifiers: [.control], character: "s")
    let script = Script(name: "Slow", scriptPath: "sleep 0.5 && echo done", shortcutKey: shortcut)
    let ctx = makeController()
    ctx.appState.settings.script.scripts = [script]

    ctx.controller.showPanel()
    ctx.appState.setInputText("original")

    #expect(ctx.controller.panel.onShortcutKey?(shortcut) == true)
    await Task.yield()

    // Cancel while script is running
    ctx.controller.cancel()

    await ctx.controller.shortcutScriptTask?.value

    // Result should be discarded because panel was cancelled
    #expect(ctx.appState.inputText == "")
    #expect(ctx.appState.isInputPanelVisible == false)
  }

  // MARK: - Script shortcuts

  @Test func cmdShiftShortcutExecutesScript() async throws {
    let scriptPath = try makeScript("echo 'cmd-shift output'")
    let cmdShiftC = ShortcutKey(modifiers: [.command, .shift], character: "c")
    let script = Script(name: "CmdShift", scriptPath: scriptPath, shortcutKey: cmdShiftC)
    let ctx = makeController()
    ctx.appState.settings.script.scripts = [script]

    ctx.controller.showPanel()
    ctx.appState.setInputText("original")

    let handled = ctx.controller.panel.onShortcutKey?(cmdShiftC)

    #expect(handled == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.inputText == "cmd-shift output")
  }

  @Test func manualUndoRestoresEditorAndRecordsOnlyConfirmedResult() async throws {
    let shortcut = ShortcutKey(modifiers: [.control], character: "u")
    let script = Script(name: "Upper", scriptPath: "tr a-z A-Z", shortcutKey: shortcut)
    let paster = MockPaster()
    let ctx = makeController(paster: paster)
    ctx.appState.settings.script.scripts = [script]

    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    textView.replaceText("hello")
    ctx.appState.setInputText("hello")
    #expect(ctx.controller.panel.onShortcutKey?(shortcut) == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.inputText == "HELLO")
    #expect(ctx.appState.scriptUndoText == "hello")
    #expect(ctx.historyStore.entries.isEmpty)

    ctx.controller.undoLastScript()
    #expect(ctx.appState.inputText == "hello")
    #expect(textView.string == "hello")
    #expect(ctx.appState.scriptUndoText == nil)
    #expect(ctx.controller.voiceCoordinator.voiceInsertionPoint == 5)
    #expect(ctx.historyStore.entries.isEmpty)

    ctx.appState.frontmostApplication = NSRunningApplication.current
    await ctx.controller.confirm()
    #expect(paster.pastedTexts == ["hello"])
    #expect(ctx.historyStore.entries.map(\.text) == ["hello"])
  }

  @Test func modifierMismatchDoesNotExecuteScript() {
    let cmdC = ShortcutKey(modifiers: [.command], character: "c")
    let cmdShiftC = ShortcutKey(modifiers: [.command, .shift], character: "c")
    let script = Script(name: "CmdC", scriptPath: "/bin/echo", shortcutKey: cmdC)
    let ctx = makeController()
    ctx.appState.settings.script.scripts = [script]

    ctx.controller.showPanel()
    ctx.appState.setInputText("original")

    // Cmd+Shift+C should NOT match Cmd+C
    let handled = ctx.controller.panel.onShortcutKey?(cmdShiftC)
    #expect(handled == false)
    #expect(ctx.appState.inputText == "original")
  }

  // MARK: - Auto-Run Script

  @Test func confirmWithAutoRunScript() async throws {
    let scriptPath = try makeScript("tr a-z A-Z")
    let script = Script(name: "Upper", scriptPath: scriptPath)
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.script.scripts = [script]
    ctx.appState.settings.script.autoRunScriptId = script.id

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(paster.pastedTexts == ["HELLO"])
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.historyStore.entries.count == 1)
    #expect(ctx.historyStore.entries[0].text == "HELLO")
    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func confirmAutoRunScriptError() async throws {
    let scriptPath = try makeScript("exit 1")
    let script = Script(name: "Fail", scriptPath: scriptPath)
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.script.scripts = [script]
    ctx.appState.settings.script.autoRunScriptId = script.id

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.offerScriptUndo(restoring: "before")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.appState.isInputPanelVisible == true)
    #expect(ctx.appState.errorMessage != nil)
    #expect(paster.pastedTexts.isEmpty)
    #expect(ctx.appState.inputText == "hello")
    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func confirmAutoRunScriptEmptyOutput() async throws {
    let scriptPath = try makeScript("printf ''")
    let script = Script(name: "Empty", scriptPath: scriptPath)
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.script.scripts = [script]
    ctx.appState.settings.script.autoRunScriptId = script.id

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
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
    ctx.appState.setInputText("hello")
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
    ctx.appState.setInputText("hello")

    let handled = ctx.controller.panel.onShortcutKey?(ctrlA)

    #expect(handled == true)
    // Auto-run cycle should have been triggered, not replacement
    #expect(ctx.appState.settings.script.autoRunScriptId == script.id)
    // Text should NOT have been replaced by replacement rules
    #expect(ctx.appState.inputText == "hello")
  }
}
