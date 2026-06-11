import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

/// Integration tests for InputPanelController against the real panel and
/// text view. Split across files by area; all tests share this suite so
/// they keep running serialized:
/// - InputPanelControllerConfirmTests.swift — confirm / history
/// - InputPanelControllerScriptTests.swift — script execution / auto-run
/// - InputPanelControllerReplacementTests.swift — replacement rules
/// - InputPanelControllerReplayTests.swift — overlap removal / replay suppression
@MainActor
@Suite(.serialized)
struct InputPanelControllerTests {
  // MARK: - Show / Cancel lifecycle

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

  @Test func showPanelClearsErrorMessage() {
    let ctx = makeController()

    ctx.appState.errorMessage = "previous error"
    ctx.controller.showPanel()

    #expect(ctx.appState.errorMessage == nil)
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

  // MARK: - Voice Input Off Mode

  @Test func showPanelWithVoiceOffSkipsDucking() {
    let ducker = MockVolumeDucker()
    let ctx = makeController(ducker: ducker)
    ctx.appState.settings.voiceInput.voiceInputMode = .off
    ctx.controller.showPanel()

    #expect(ducker.duckCallCount == 0)
  }

  @Test func showPanelWithVoiceOnDucks() {
    let ducker = MockVolumeDucker()
    let ctx = makeController(ducker: ducker)
    ctx.appState.settings.voiceInput.voiceInputMode = .dictation
    ctx.controller.showPanel()

    #expect(ducker.duckCallCount == 1)
  }

  @Test func confirmWithVoiceOffIsIdempotent() async {
    let ctx = makeController()
    ctx.appState.settings.voiceInput.voiceInputMode = .off
    ctx.controller.showPanel()

    // confirm with empty text — should not crash
    await ctx.controller.confirm()
    #expect(ctx.appState.isInputPanelVisible == false)
  }

  @Test func cancelWithVoiceOffIsIdempotent() {
    let ctx = makeController()
    ctx.appState.settings.voiceInput.voiceInputMode = .off
    ctx.controller.showPanel()

    ctx.controller.cancel()
    #expect(ctx.appState.isInputPanelVisible == false)
  }
}
