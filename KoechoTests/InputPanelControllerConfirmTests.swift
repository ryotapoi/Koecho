import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// MARK: - confirm

extension InputPanelControllerTests {
  @Test func confirmSuccessClearsState() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
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
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.appState.isInputPanelVisible == true)
    #expect(ctx.appState.inputText == "hello")
    #expect(ctx.appState.errorMessage != nil)
    #expect(paster.restoreClipboardCallCount == 1)
  }

  @Test func accessibilityFailureRetriesSameTargetWithoutRestartingVoiceInput() async {
    let paster = MockPaster()
    paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
    let engine = MockVoiceInputEngine()
    let ctx = makeController(paster: paster, makeEngine: { engine })
    let targetApp = NSRunningApplication.current

    ctx.controller.showPanel()
    await Task.yield()
    let startCallCountBeforeFailure = engine.startCallCount
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = targetApp

    await ctx.controller.confirm()

    #expect(paster.restoreClipboardCallCount == 1)
    #expect(ctx.appState.frontmostApplication === targetApp)
    #expect(engine.startCallCount == startCallCountBeforeFailure)

    paster.errorToThrow = nil
    await ctx.controller.confirm()

    #expect(paster.pastedApplications.count == 2)
    #expect(paster.pastedApplications[0] === targetApp)
    #expect(paster.pastedApplications[1] === targetApp)
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.frontmostApplication == nil)
    #expect(ctx.appState.inputText == "")
    #expect(ctx.historyStore.entries.map(\.text) == ["hello"])
  }

  @Test func terminatedTargetCancelsRetryAndReopensEmptyPanel() async {
    let paster = MockPaster()
    paster.errorToThrow = ClipboardPasterError.targetAppTerminated
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(paster.restoreClipboardCallCount == 1)
    #expect(ctx.appState.isInputPanelVisible == true)
    #expect(ctx.appState.frontmostApplication == nil)
    #expect(ctx.appState.inputText == "")
    #expect(ctx.appState.errorMessage == String(localized: "Target application has been terminated."))
  }

  @Test func confirmWithEmptyTextActsAsCancel() async {
    let ctx = makeController()

    ctx.controller.showPanel()
    ctx.appState.setInputText("   \n  ")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.inputText == "")
    #expect(ctx.appState.frontmostApplication == nil)
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
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = nil

    await ctx.controller.confirm()

    #expect(ctx.appState.errorMessage == String(localized: "No target application"))
    #expect(ctx.appState.isInputPanelVisible == true)
  }

  @Test func cancelDuringConfirmIsIgnored() async throws {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    // Make paste suspend so we can call cancel() while confirm() is in progress.
    paster.suspendsPaste = true

    // Start confirm in a Task so we can call cancel() after it begins
    let confirmTask = Task { @MainActor in
      await ctx.controller.confirm()
    }
    await paster.waitForPasteStart()

    // Panel should be hidden (confirm hides it before paste) but isConfirming is true
    // cancel() should be ignored because isConfirming is true
    ctx.controller.cancel()

    paster.finishPaste()
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

  // MARK: - History

  @Test func confirmRecordsHistory() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
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
    ctx.appState.setInputText("えーと今日はいい天気")
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
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.historyStore.entries.isEmpty)
  }

  @Test func confirmDoesNotRecordOnPasteFailure() async {
    let paster = MockPaster()
    paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.historyStore.entries.isEmpty)
  }

  @Test func confirmDoesNotRecordEmptyText() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("   \n  ")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.historyStore.entries.isEmpty)
  }
}
