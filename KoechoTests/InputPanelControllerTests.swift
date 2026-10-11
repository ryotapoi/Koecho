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
/// - InputPanelControllerReplayTests.swift — speech after local finalization
@MainActor
@Suite(.serialized)
struct InputPanelControllerTests {
  // MARK: - Show / Cancel lifecycle

  @Test func minimumFrameRemainsReachableWithHostedContent() async throws {
    let ctx = makeController()
    let panel = ctx.controller.panel
    // Keep this resize from writing the standard domain's saved frame.
    panel.setFrameAutosaveName("")
    panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 180), display: false)
    ctx.controller.showPanel()
    await Task.yield()
    panel.contentView?.layoutSubtreeIfNeeded()

    #expect(panel.frame.size == NSSize(width: 320, height: 180))
    #expect(panel.contentView?.fittingSize == NSSize(width: 320, height: 180))
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    let editorViewport = try #require(textView.enclosingScrollView)
    #expect(editorViewport.visibleRect.width > 0)
    #expect(editorViewport.visibleRect.height > 0)
    let savedFrame = NSRect(x: 120, y: 180, width: 460, height: 320)
    panel.setFrame(savedFrame, display: false)
    ctx.controller.cancel()
    ctx.controller.showPanel()
    ctx.appState.promptScript = Script(
      name: "Prompt", scriptPath: "prompt.sh", requiresPrompt: true)
    await Task.yield()
    panel.contentView?.layoutSubtreeIfNeeded()
    #expect(panel.frame == savedFrame)
    #expect(panel.contentView?.fittingSize == NSSize(width: 320, height: 180))
    ctx.controller.cancel()
  }

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

  @Test(arguments: [false, true])
  func closingPanelRetainsDisplayedMarkedAndVolatileContent(closeButton: Bool) async throws {
    let ctx = makeController()
    ctx.controller.showPanel()
    await Task.yield()
    let view = try #require(findVoiceInputTextView(in: ctx.controller))
    view.replaceText("  body")
    ctx.appState.setInputText("stale finalized text")
    view.setVolatileText(" voice", at: (view.string as NSString).length)
    view.setMarkedText(
      "変換中", selectedRange: NSRange(location: 3, length: 0),
      replacementRange: NSRange(location: (view.string as NSString).length, length: 0))
    let displayed = view.string
    #expect(displayed.contains(" voice"))
    #expect(displayed.contains("変換中"))
    if closeButton { ctx.controller.panel.close() } else { ctx.controller.panel.onEscape?() }
    #expect(!ctx.appState.isInputPanelVisible)
    #expect(ctx.appState.lastContent == displayed)
    #expect(ctx.historyStore.entries.isEmpty)
    ctx.controller.showPanel()
    await Task.yield()
    #expect(ctx.appState.lastContent == displayed)
    ctx.appState.setInputText("stale state must not replace empty editor")
    view.replaceText("")
    ctx.controller.cancel()
    #expect(ctx.appState.lastContent == displayed)
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
    #expect(ctx.appState.lastContent == nil)
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

  // MARK: - Language switching

  @Test(arguments: [false, true])
  func escapeDuringLanguageSwitchDiscardsLateStop(reopen: Bool) async throws {
    var engines: [MockVoiceInputEngine] = []
    let ctx = makeController(makeEngine: {
      let engine = MockVoiceInputEngine()
      engines.append(engine)
      return engine
    })
    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    let oldEngine = try #require(engines.last)
    #expect(oldEngine.state == .listening)
    let stopStarted = AsyncStream<Void>.makeStream()
    let finishStop = AsyncStream<Void>.makeStream()
    defer {
      finishStop.continuation.finish()
      stopStarted.continuation.finish()
      ctx.controller.cancel()
    }
    oldEngine.onStop = {
      stopStarted.continuation.yield(())
      for await _ in finishStop.stream { break }
    }
    ctx.appState.settings.voiceInput.speechAnalyzerLocale = "en-US"
    let switchTask = Task { await ctx.controller.switchEngine() }
    for await _ in stopStarted.stream { break }
    #expect(oldEngine.state == .stopping)
    ctx.controller.panel.onEscape?()
    #expect(!ctx.appState.isInputPanelVisible)
    #expect(!ctx.controller.panel.isVisible)
    #expect(oldEngine.cancelCallCount == 1)

    if reopen {
      ctx.controller.showPanel()
      await Task.yield()
      textView.replaceText("next session")
      ctx.appState.setInputText("next session")
      textView.setSelectedRange(NSRange(location: 2, length: 0))
      ctx.controller.voiceCoordinator.handleCursorMoved(2)
      textView.setVolatileText("draft", at: 2)
    }
    let expectedEngines = engines.count
    let currentEngine = try #require(engines.last)
    let expectedText = textView.string
    let expectedSelection = textView.selectedRange()
    let expectedVolatileRange = textView.volatileRange
    finishStop.continuation.yield(())
    await switchTask.value

    #expect(engines.count == expectedEngines)
    #expect(oldEngine.startCallCount == 1)
    #expect(ctx.appState.isInputPanelVisible == reopen)
    #expect(ctx.controller.panel.isVisible == reopen)
    if reopen {
      #expect(ctx.controller.voiceCoordinator.engine === currentEngine)
      #expect(currentEngine.state == .listening)
      #expect(textView.string == expectedText)
      #expect(textView.selectedRange() == expectedSelection)
      #expect(textView.volatileRange == expectedVolatileRange)
      #expect(ctx.appState.inputText == "next session")
      #expect(ctx.controller.voiceCoordinator.voiceInsertionPoint == 2)
      currentEngine.delegate?.voiceInput(didFinalize: "new")
      #expect(ctx.appState.inputText == "nenewxt session")
    } else {
      #expect(oldEngine.state == .idle)
      #expect(ctx.appState.inputText.isEmpty)
    }
  }

  @Test func languageSwitchStartsSelectedEngineAndNextShowUsesSelection() async throws {
    var appState: AppState?
    var engines: [MockVoiceInputEngine] = []
    var locales: [String?] = []
    let ctx = makeController(makeEngine: {
      let engine = MockVoiceInputEngine()
      engines.append(engine)
      locales.append(appState?.settings.voiceInput.speechAnalyzerLocale)
      return engine
    })
    appState = ctx.appState
    ctx.appState.settings.voiceInput.speechAnalyzerLocale = "ja-JP"
    ctx.controller.showPanel()
    await Task.yield()
    let oldEngine = try #require(engines.last)
    let stopStarted = AsyncStream<Void>.makeStream()
    let finishStop = AsyncStream<Void>.makeStream()
    defer {
      finishStop.continuation.finish()
      stopStarted.continuation.finish()
      ctx.controller.cancel()
    }
    oldEngine.onStop = {
      stopStarted.continuation.yield(())
      for await _ in finishStop.stream { break }
    }
    ctx.appState.settings.voiceInput.speechAnalyzerLocale = "en-US"
    let countBeforeSwitch = engines.count
    let switchTask = Task { await ctx.controller.switchEngine() }
    for await _ in stopStarted.stream { break }
    #expect(engines.count == countBeforeSwitch)
    finishStop.continuation.yield(())
    await switchTask.value
    let switchedEngine = try #require(engines.last)
    #expect(switchedEngine !== oldEngine)
    #expect(oldEngine.state == .idle)
    #expect(switchedEngine.state == .listening)
    #expect(locales.last == "en-US")

    ctx.controller.panel.onEscape?()
    ctx.controller.showPanel()
    await Task.yield()
    let nextEngine = try #require(engines.last)
    #expect(nextEngine !== switchedEngine)
    #expect(nextEngine.state == .listening)
    #expect(locales.last == "en-US")
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
