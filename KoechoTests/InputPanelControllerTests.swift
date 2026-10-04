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
    ctx.appState.setInputText("some text")
    ctx.appState.frontmostApplication = NSRunningApplication.current
    ctx.controller.cancel()

    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.inputText == "")
    #expect(ctx.appState.frontmostApplication == nil)
    #expect(!ctx.controller.panel.isVisible)
  }

  @Test func closeButtonCancelsPanel() {
    let ctx = makeController()

    ctx.controller.showPanel()
    ctx.appState.setInputText("some text")
    ctx.controller.panel.close()

    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.inputText == "")
  }

  @Test func showPanelTwicePreservesText() {
    let ctx = makeController()

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.controller.showPanel()

    #expect(ctx.appState.inputText == "hello")
    #expect(ctx.appState.isInputPanelVisible == true)
  }

  @Test func cancelWhenNotVisibleIsNoop() {
    let ctx = makeController()
    ctx.appState.setInputText("retained")

    ctx.controller.cancel()

    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.inputText == "retained")
    #expect(ctx.paster.restoreClipboardCallCount == 0)
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

  // MARK: - Selected Text as Initial Input

  @Test func showPanelWithSelectedTextSetsInputText() async throws {
    let mockReader = MockSelectedTextReader()
    mockReader.resultToReturn = SelectedTextResult(text: "selected text")
    let ctx = makeController(selectedTextReader: mockReader)

    ctx.controller.showPanel()

    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    #expect(ctx.appState.inputText == "selected text")
    #expect(textView.string == "selected text")
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
    #expect(ducker.duckCallCount == 1)
    ctx.controller.showPanel()
    #expect(ducker.duckCallCount == 1)
  }

  // MARK: - Voice Input Off Mode

  @Test func showPanelWithVoiceOffSkipsDucking() {
    let ducker = MockVolumeDucker()
    let ctx = makeController(ducker: ducker)
    ctx.appState.settings.voiceInput.isVoiceInputEnabled = false
    ctx.controller.showPanel()

    #expect(ducker.duckCallCount == 0)
  }

  @Test func voiceShortcutTogglesOnlyInsidePanel() async {
    let ctx = makeController()
    let key = ShortcutKey(modifiers: [.control], character: "v")
    ctx.appState.settings.voiceInput.voiceInputShortcutKey = key
    #expect(ctx.controller.panel.onShortcutKey?(key) == false)

    ctx.controller.showPanel()
    #expect(ctx.controller.panel.onShortcutKey?(key) == true)
    await ctx.controller.voiceShortcutTask?.value
    #expect(!ctx.appState.settings.voiceInput.isVoiceInputEnabled)

    #expect(ctx.controller.panel.onShortcutKey?(key) == true)
    await ctx.controller.voiceShortcutTask?.value
    #expect(ctx.appState.settings.voiceInput.isVoiceInputEnabled)

    ctx.controller.cancel()
    #expect(ctx.controller.panel.onShortcutKey?(key) == false)
  }

  @Test func voiceShortcutDoesNotHandleUnassignedOrDifferentKey() {
    let ctx = makeController()
    let key = ShortcutKey(modifiers: [.control], character: "v")
    ctx.controller.showPanel()
    #expect(ctx.controller.panel.onShortcutKey?(key) == false)
    ctx.appState.settings.voiceInput.voiceInputShortcutKey = key
    #expect(
      ctx.controller.panel.onShortcutKey?(ShortcutKey(modifiers: [.option], character: "v"))
        == false)
  }

  @Test(arguments: [false, true])
  func enablingVoiceFromOffPreservesRecognitionLocale(usingShortcut: Bool) async {
    let ctx = makeController()
    let key = ShortcutKey(modifiers: [.control], character: "v")
    ctx.appState.settings.voiceInput.isVoiceInputEnabled = false
    ctx.appState.settings.voiceInput.speechAnalyzerLocale = "ja-JP"
    ctx.appState.settings.voiceInput.voiceInputShortcutKey = key
    ctx.controller.showPanel()

    if usingShortcut {
      #expect(ctx.controller.panel.onShortcutKey?(key) == true)
      await ctx.controller.voiceShortcutTask?.value
    } else {
      await ctx.controller.toggleVoiceInput()
    }

    #expect(ctx.appState.settings.voiceInput.isVoiceInputEnabled)
    #expect(ctx.appState.settings.voiceInput.speechAnalyzerLocale == "ja-JP")
    ctx.controller.cancel()
  }
}
