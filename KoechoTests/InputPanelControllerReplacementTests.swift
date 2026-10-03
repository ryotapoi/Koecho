import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// MARK: - Replacement Rules on Confirm

extension InputPanelControllerTests {
  @Test func confirmAppliesReplacementRules() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello world")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(paster.pastedTexts == ["bye world"])
    #expect(ctx.historyStore.entries.map(\.text) == ["bye world"])
  }

  @Test func confirmWithReplacementRulesEmptyingText() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: ".*", replacement: "", usesRegularExpression: true)
    )

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    // All text removed by replacement → treated as cancel
    #expect(paster.pastedTexts.isEmpty)
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(paster.restoreClipboardCallCount == 1)
  }

  // MARK: - Replacement shortcuts

  @Test func shortcutRAppliesReplacementRules() {
    let ctx = makeController()
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    ctx.controller.showPanel()
    ctx.appState.setInputText("えーと天気")

    let handled = ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "r"))

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

    // Ctrl+X should apply replacement rules
    let handledX = ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "x"))
    #expect(handledX == true)
    #expect(ctx.appState.inputText == "天気")

    // Ctrl+R should NOT apply replacement rules (no longer the shortcut)
    ctx.appState.setInputText("えーと天気")
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
