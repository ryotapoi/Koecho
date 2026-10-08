import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// MARK: - Replacement Rules on Confirm

extension InputPanelControllerTests {
  @Test(arguments: [true, false])
  func confirmHonorsAutoReplacement(isAutomatic: Bool) async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )

    ctx.controller.showPanel()
    ctx.appState.settings.replacement.isAutoReplacementEnabled = isAutomatic
    ctx.appState.setInputText("  hello world\n")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    let expected = isAutomatic ? "bye world" : "hello world"
    #expect(paster.pastedTexts == [expected])
    #expect(ctx.historyStore.entries.map(\.text) == [expected])
  }

  @Test(arguments: [true, false])
  func confirmWithDeletionRuleHonorsAutoReplacement(isAutomatic: Bool) async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: ".*", replacement: "", usesRegularExpression: true)
    )

    ctx.controller.showPanel()
    ctx.appState.settings.replacement.isAutoReplacementEnabled = isAutomatic
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(paster.pastedTexts == (isAutomatic ? [] : ["hello"]))
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(paster.restoreClipboardCallCount == (isAutomatic ? 1 : 0))
  }

  @Test func confirmPreservesRemainingAndGeneratedManualCandidates() async throws {
    let ctx = makeController()
    ctx.appState.settings.replacement.isAutoReplacementEnabled = false
    ctx.appState.settings.replacement.replacementRules = [
      ReplacementRule(pattern: "a", replacement: "long"),
      ReplacementRule(pattern: "long", replacement: "x")]
    ctx.controller.showPanel()
    let view = try #require(findVoiceInputTextView(in: ctx.controller))
    ctx.appState.setInputText("a a")
    view.replaceText("a a", selecting: NSRange(location: 0, length: 1))
    #expect(ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "r")) == true)
    #expect(ctx.appState.inputText == "long a")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.paster.pastedTexts == ["long a"])
    #expect(ctx.historyStore.entries.map(\.text) == ["long a"])
  }

  @Test func confirmPreservesFinalAndRemainingVolatileSpeechWhenAutomaticReplacementIsOff() async throws {
    let engine = MockVoiceInputEngine()
    let ctx = makeController(makeEngine: { engine })
    ctx.appState.settings.replacement.isAutoReplacementEnabled = false
    ctx.appState.settings.replacement.replacementRules = [
      ReplacementRule(pattern: "hello", replacement: "bye"),
      ReplacementRule(pattern: "world", replacement: "earth")]
    ctx.controller.showPanel()
    await Task.yield()
    _ = try #require(findVoiceInputTextView(in: ctx.controller))
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")
    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: " world")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.paster.pastedTexts == ["hello world"])
    #expect(ctx.historyStore.entries.map(\.text) == ["hello world"])
  }

  // MARK: - Replacement shortcuts

  @Test func shortcutRAppliesReplacementRules() {
    let ctx = makeController()
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    ctx.controller.showPanel()
    ctx.appState.setInputText("えーと天気")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("えーと天気", selecting: NSRange(location: 1, length: 0))

    let handled = ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "r"))

    #expect(handled == true)
    #expect(ctx.appState.inputText == "天気")
  }

  @Test func replacementShortcutUsesCurrentSelectionWithoutChaining() throws {
    let ctx = makeController()
    ctx.appState.settings.replacement.isAutoReplacementEnabled = false
    ctx.appState.settings.replacement.replacementRules = [
      ReplacementRule(pattern: "a", replacement: "long"),
      ReplacementRule(pattern: "long", replacement: "x")]
    ctx.controller.showPanel()
    let view = try #require(findVoiceInputTextView(in: ctx.controller))
    ctx.appState.setInputText("a aZ")
    view.replaceText("a aZ", selecting: NSRange(location: 1, length: 0))
    let key = ShortcutKey(modifiers: [.control], character: "r")
    #expect(ctx.controller.panel.onShortcutKey?(key) == true)
    #expect(ctx.appState.inputText == "long aZ")
    view.setSelectedRange(NSRange(location: 0, length: 6))
    #expect(ctx.controller.panel.onShortcutKey?(key) == true)
    #expect(ctx.appState.inputText == "x longZ")
    ctx.appState.settings.replacement.replacementShortcutKey = nil
    #expect(ctx.controller.panel.onShortcutKey?(key) == false)
    #expect(ctx.appState.inputText == "x longZ")
  }

  @Test func shortcutRFallsBackToScriptWhenNoRules() async throws {
    let scriptPath = try makeScript("echo 'script output'")
    let ctrlR = ShortcutKey(modifiers: [.control], character: "r")
    let script = Script(name: "R Script", scriptPath: scriptPath, shortcutKey: ctrlR)
    let ctx = makeController()
    ctx.appState.settings.script.scripts = [script]
    // No replacement rules — Ctrl+R should fall through to script

    ctx.controller.showPanel()
    ctx.appState.setInputText("original")

    let handled = ctx.controller.panel.onShortcutKey?(ctrlR)

    #expect(handled == true)
    await ctx.controller.shortcutScriptTask?.value
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
    ctx.appState.setInputText("えーと天気")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("えーと天気", selecting: NSRange(location: 1, length: 0))

    let handled = ctx.controller.panel.onShortcutKey?(ctrlR)

    #expect(handled == true)
    // Text should be replaced by replacement rules, not by script
    #expect(ctx.appState.inputText == "天気")
  }

  @Test func customShortcutKeyAppliesReplacementRules() {
    let ctx = makeController()
    ctx.appState.settings.replacement.replacementShortcutKey = ShortcutKey(
      modifiers: [.control], character: "x")
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    ctx.controller.showPanel()
    ctx.appState.setInputText("えーと天気")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("えーと天気", selecting: NSRange(location: 1, length: 0))

    // Ctrl+X should apply replacement rules
    let handledX = ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "x"))
    #expect(handledX == true)
    #expect(ctx.appState.inputText == "天気")

    // Ctrl+R should NOT apply replacement rules (no longer the shortcut)
    ctx.appState.setInputText("えーと天気")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("えーと天気", selecting: NSRange(location: 1, length: 0))
    let handledR = ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "r"))
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
    ctx.appState.setInputText("えーと天気")
    findVoiceInputTextView(in: ctx.controller)?.replaceText("えーと天気", selecting: NSRange(location: 1, length: 0))

    // Ctrl+R should fall through to script (replacement shortcut is nil)
    let handled = ctx.controller.panel.onShortcutKey?(ctrlR)
    #expect(handled == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.inputText == "script output")
  }

  // MARK: - Auto Replacement

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
}
