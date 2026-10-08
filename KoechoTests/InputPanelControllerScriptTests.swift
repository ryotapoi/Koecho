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

  @Test(arguments: [false, true])
  func escapeStopsScriptAndOldCompletionCannotClearNextRun(autoRun: Bool) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let ctx = makeController(makeScriptRunner: { ScriptRunner(timeout: 20, killDelay: 0.2) })
    let shortcut = ShortcutKey(modifiers: [.control], character: "s")
    func script(_ name: String) -> Script {
      Script(name: name, scriptPath: "trap '' TERM; echo $$ > '\(directory.path)/\(name)'; while :; do :; done", shortcutKey: shortcut)
    }
    func waitForPID(_ name: String) async throws -> Int32 {
      let marker = directory.appendingPathComponent(name)
      let deadline = ContinuousClock.now + .seconds(5)
      while !FileManager.default.fileExists(atPath: marker.path), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
      }
      return try #require(Int32(try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    func waitForExit(_ pid: Int32) async throws {
      let deadline = ContinuousClock.now + .seconds(5)
      while kill(pid, 0) == 0, ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
      }
      #expect(kill(pid, 0) == -1 && errno == ESRCH)
    }
    let first = script("first")
    ctx.appState.settings.script.scripts = [first]
    ctx.appState.settings.script.autoRunScriptId = autoRun ? first.id : nil
    ctx.controller.showPanel()
    ctx.appState.setInputText("original")
    ctx.appState.frontmostApplication = NSRunningApplication.current
    let firstTask: Task<Void, Never>
    if autoRun {
      firstTask = Task { await ctx.controller.confirm() }
    } else {
      #expect(ctx.controller.panel.onShortcutKey?(shortcut) == true)
      firstTask = try #require(ctx.controller.shortcutScriptTask)
    }
    let firstPID = try await waitForPID("first")
    ctx.controller.panel.onEscape?()
    ctx.controller.showPanel()
    let second = script("second")
    ctx.appState.settings.script.scripts = [second]
    ctx.appState.settings.script.autoRunScriptId = nil
    ctx.appState.setInputText("new text")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("new text")
    #expect(ctx.controller.panel.onShortcutKey?(shortcut) == true)
    let secondTask = try #require(ctx.controller.shortcutScriptTask)
    let secondPID = try await waitForPID("second")
    await firstTask.value
    try await waitForExit(firstPID)
    #expect(ctx.appState.isRunningScript)
    #expect(ctx.appState.inputText == "new text")
    #expect(ctx.appState.errorMessage == nil)
    #expect(kill(secondPID, 0) == 0)
    #expect(ctx.paster.pastedTexts.isEmpty)
    #expect(ctx.historyStore.entries.isEmpty)
    ctx.controller.panel.onEscape?()
    await secondTask.value
    try await waitForExit(secondPID)
    #expect(!ctx.appState.isRunningScript)
    ctx.controller.showPanel()
    ctx.appState.setInputText("recovery")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("recovery")
    ctx.appState.settings.script.scripts = [Script(name: "Upper", scriptPath: "tr a-z A-Z", shortcutKey: shortcut)]
    #expect(ctx.controller.panel.onShortcutKey?(shortcut) == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.inputText == "RECOVERY")
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

  @Test(arguments: [true, false])
  func confirmWithAutoRunScriptHonorsAutoReplacement(isAutomatic: Bool) async throws {
    let scriptPath = try makeScript("tr a-z A-Z")
    let script = Script(name: "Upper", scriptPath: scriptPath)
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.script.scripts = [script]
    ctx.appState.settings.script.autoRunScriptId = script.id

    ctx.appState.settings.replacement.isAutoReplacementEnabled = isAutomatic
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye"))
    ctx.controller.showPanel()
    ctx.appState.setInputText("  hello\n")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    let expected = isAutomatic ? "BYE" : "HELLO"
    #expect(paster.pastedTexts == [expected])
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.historyStore.entries.count == 1)
    #expect(ctx.historyStore.entries[0].text == expected)
    #expect(ctx.appState.scriptUndoText == nil)
  }

  @Test func childHeldPipeTimeoutRestoresAutoRunFallbackAndAllowsEditing() async {
    let ctx = makeController()
    ctx.appState.settings.script.scriptTimeout = 0.2
    let script = Script(name: "Pipe holder", scriptPath: "sleep 2 & printf done")
    ctx.appState.settings.script.scripts = [script]
    ctx.appState.settings.script.autoRunScriptId = script.id
    ctx.controller.showPanel()
    ctx.appState.setInputText("  original  ")
    ctx.appState.frontmostApplication = NSRunningApplication.current
    await ctx.controller.confirm()
    #expect(ctx.appState.inputText == "original")
    #expect(ctx.appState.errorMessage != nil)
    #expect(ctx.appState.isInputPanelVisible)
    #expect(!ctx.appState.isRunningScript)
    #expect(ctx.paster.pastedTexts.isEmpty)
    findVoiceInputTextView(in: ctx.controller)?.replaceText("edited")
    ctx.appState.setInputText("edited")
    let success = Script(name: "Uppercase", scriptPath: "tr a-z A-Z")
    ctx.appState.settings.script.scripts = [success]
    ctx.appState.settings.script.autoRunScriptId = success.id
    await ctx.controller.confirm()
    #expect(ctx.paster.pastedTexts == ["EDITED"])
    #expect(!ctx.appState.isInputPanelVisible)
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
    ctx.appState.settings.voiceInput.voiceInputShortcutKey = ctrlA
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
    #expect(ctx.appState.settings.voiceInput.isVoiceInputEnabled)
  }

  @Test func replacementAndScriptTakePriorityOverVoiceShortcut() async throws {
    let ctx = makeController()
    let key = ShortcutKey(modifiers: [.control], character: "v")
    ctx.appState.settings.voiceInput.voiceInputShortcutKey = key
    ctx.appState.settings.replacement.replacementShortcutKey = key
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )
    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("hello", selecting: NSRange(location: 0, length: 0))
    #expect(ctx.controller.panel.onShortcutKey?(key) == true)
    #expect(ctx.appState.inputText == "bye")
    #expect(ctx.appState.settings.voiceInput.isVoiceInputEnabled)

    ctx.appState.settings.replacement.replacementRules = []
    let scriptPath = try makeScript("echo 'script output'")
    ctx.appState.settings.script.scripts = [
      Script(name: "Voice Collision", scriptPath: scriptPath, shortcutKey: key)
    ]
    #expect(ctx.controller.panel.onShortcutKey?(key) == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.inputText == "script output")
    #expect(ctx.appState.settings.voiceInput.isVoiceInputEnabled)
  }
}
