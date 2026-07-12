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

  // MARK: - Replacement shortcuts

  @Test func shortcutRAppliesReplacementRules() {
    let ctx = makeController()
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    ctx.controller.showPanel()
    ctx.appState.inputText = "えーと天気"

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
    ctx.appState.inputText = "original"

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
    ctx.appState.inputText = "えーと天気"

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
    ctx.appState.inputText = "えーと天気"

    // Ctrl+X should apply replacement rules
    let handledX = ctx.controller.panel.onShortcutKey?(
      ShortcutKey(modifiers: [.control], character: "x"))
    #expect(handledX == true)
    #expect(ctx.appState.inputText == "天気")

    // Ctrl+R should NOT apply replacement rules (no longer the shortcut)
    ctx.appState.inputText = "えーと天気"
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
    ctx.appState.inputText = "えーと天気"

    // Ctrl+R should fall through to script (replacement shortcut is nil)
    let handled = ctx.controller.panel.onShortcutKey?(ctrlR)
    #expect(handled == true)
    await ctx.controller.shortcutScriptTask?.value
    #expect(ctx.appState.inputText == "script output")
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
}
