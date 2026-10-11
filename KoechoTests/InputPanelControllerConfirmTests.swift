import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// MARK: - confirm

extension InputPanelControllerTests {
  @Test func reusedControllerUsesLatestPasteDelay() async throws {
    let ctx = makeController()
    ctx.appState.settings.voiceInput.isVoiceInputEnabled = false
    ctx.appState.settings.paste.pasteDelay = 2
    defer { ctx.controller.panel.close() }

    for (delay, text) in [(2.0, "first"), (10.0, "second")] {
      ctx.appState.settings.paste.pasteDelay = delay
      ctx.controller.showPanel()
      await Task.yield()
      let textView = try #require(findVoiceInputTextView(in: ctx.controller))
      textView.replaceText(text)
      ctx.appState.setInputText(text)
      ctx.appState.frontmostApplication = NSRunningApplication.current
      await ctx.controller.confirm()
    }

    #expect(ctx.paster.pastedTexts == ["first", "second"])
    #expect(ctx.paster.pastedDelays == [2, 10])
  }

  @Test(arguments: ["hello", ""])
  func repeatedConfirmWaitsForFinalSpeech(initialText: String) async throws {
    let engine = MockVoiceInputEngine()
    let ctx = makeController(makeEngine: { engine })
    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    textView.replaceText(initialText)
    ctx.appState.setInputText(initialText)
    ctx.appState.frontmostApplication = NSRunningApplication.current

    let stopStarted = AsyncStream<Void>.makeStream()
    let finishStop = AsyncStream<Void>.makeStream()
    engine.onStop = {
      // Model the real engine's immediate return on a second stop request.
      guard engine.stopCallCount == 1 else { return }
      stopStarted.continuation.yield(())
      for await _ in finishStop.stream { break }
    }
    defer {
      stopStarted.continuation.finish()
      finishStop.continuation.finish()
    }
    let confirmTask = Task { await ctx.controller.confirm() }
    for await _ in stopStarted.stream { break }

    await ctx.controller.confirm()
    await ctx.controller.confirm()
    #expect(ctx.appState.isInputPanelVisible)
    #expect(ctx.paster.pastedTexts.isEmpty)
    #expect(ctx.paster.restoreClipboardCallCount == 0)
    #expect(textView.string == initialText)

    textView.setSelectedRange(NSRange(location: (initialText as NSString).length, length: 0))
    ctx.controller.voiceCoordinator.handleCursorMoved((initialText as NSString).length)
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: " world")
    finishStop.continuation.yield(())
    await confirmTask.value

    let expected = initialText.isEmpty ? "world" : "hello world"
    #expect(ctx.paster.pastedTexts == [expected])
    #expect(ctx.historyStore.entries.map(\.text) == [expected])
    #expect(ctx.appState.lastContent == expected)
    #expect(!ctx.appState.isInputPanelVisible)

    ctx.controller.showPanel()
    await Task.yield()
    textView.replaceText("next")
    ctx.appState.setInputText("next")
    ctx.appState.frontmostApplication = NSRunningApplication.current
    await ctx.controller.confirm()
    #expect(ctx.paster.pastedTexts == [expected, "next"])
  }

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
    #expect(ctx.appState.lastContent == "hello")
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

  @Test(arguments: [ClipboardPasterError.accessibilityNotTrusted, .failedToCreateCGEvent])
  func pasteFailureRetriesSameTargetWithoutRestartingVoiceInput(error: ClipboardPasterError)
    async throws
  {
    let paster = MockPaster()
    paster.errorToThrow = error
    let engine = MockVoiceInputEngine()
    let ctx = makeController(paster: paster, makeEngine: { engine })
    let targetApp = NSRunningApplication.current

    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    let startCallCountBeforeFailure = engine.startCallCount
    // The mock paster cannot exercise real TCC; it fixes the controller's
    // transformed-text, target, retry, history, and cleanup contract.
    textView.replaceText("こんにちは")
    ctx.appState.setInputText("こんにちは")
    ctx.appState.frontmostApplication = targetApp

    await ctx.controller.confirm()

    #expect(ctx.appState.isInputPanelVisible)
    #expect(ctx.controller.panel.isVisible)
    #expect(ctx.appState.inputText == "こんにちは")
    #expect(textView.string == "こんにちは")
    #expect(ctx.appState.errorMessage != nil)
    #expect(ctx.historyStore.entries.isEmpty)
    #expect(ctx.appState.lastContent == "こんにちは")
    #expect(paster.restoreClipboardCallCount == 1)
    #expect(ctx.appState.frontmostApplication === targetApp)
    #expect(engine.startCallCount == startCallCountBeforeFailure)

    paster.errorToThrow = nil
    await ctx.controller.confirm()

    #expect(paster.pastedTexts == ["こんにちは"])
    #expect(paster.pastedApplications.count == 2)
    #expect(paster.pastedApplications[0] === targetApp)
    #expect(paster.pastedApplications[1] === targetApp)
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.frontmostApplication == nil)
    #expect(ctx.appState.inputText == "")
    #expect(ctx.historyStore.entries.map(\.text) == ["こんにちは"])
  }

  @Test func accessibilityFailureRehydratesEditorForImmediateRetryWithoutRestartingVoiceInput()
    async throws
  {
    let paster = MockPaster()
    paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
    let engine = MockVoiceInputEngine()
    let ctx = makeController(paster: paster, makeEngine: { engine })
    let targetApp = NSRunningApplication.current

    let hostingView = try #require(ctx.controller.panel.contentView)
    let contentView = NSView(frame: hostingView.frame)
    let focusSink = NSTextView(frame: .zero)
    // NSHostingView only supports SwiftUI-managed subviews, so use a shared parent.
    ctx.controller.panel.contentView = contentView
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(hostingView)
    contentView.addSubview(focusSink)
    NSLayoutConstraint.activate([
      hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])

    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller), "textView not found")
    let startCallCountBeforeFailure = engine.startCallCount
    let stopCallCountBeforeFailure = engine.stopCallCount
    let cancelCallCountBeforeFailure = engine.cancelCallCount
    let text = "こんにちは"
    ctx.appState.setInputText(text)
    ctx.appState.frontmostApplication = targetApp
    // orderOut does not clear NSWindow.firstResponder in this test host, so
    // model the focus transfer that occurs while the target app is activated.
    paster.onPasteAttempt = {
      ctx.controller.panel.initialFirstResponder = focusSink
      ctx.controller.panel.makeFirstResponder(nil)
      #expect(ctx.controller.panel.firstResponder !== textView)
    }

    await ctx.controller.confirm()
    await Task.yield()

    #expect(ctx.appState.inputText == text)
    #expect(textView.string == text)
    #expect(ctx.controller.panel.firstResponder === textView)
    #expect(textView.selectedRange() == NSRange(location: (text as NSString).length, length: 0))
    #expect(ctx.appState.frontmostApplication === targetApp)
    #expect(engine.startCallCount == startCallCountBeforeFailure)
    #expect(engine.stopCallCount == stopCallCountBeforeFailure + 1)
    #expect(engine.cancelCallCount == cancelCallCountBeforeFailure)
    #expect(engine.state == .idle)
  }

  @Test(arguments: [true, false])
  func confirmCommitsMarkedJapaneseTextBeforeStoppingVoiceInput(isAutomatic: Bool) async throws {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    await Task.yield()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller), "textView not found")
    ctx.appState.settings.replacement.isAutoReplacementEnabled = isAutomatic
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "こんにちは", replacement: "こんばんは"))
    textView.setMarkedText(
      "こんにちは",
      selectedRange: NSRange(location: 5, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: 0)
    )
    #expect(textView.hasMarkedText())
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(paster.pastedTexts == [isAutomatic ? "こんばんは" : "こんにちは"])
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
    #expect(ctx.appState.lastContent == "hello")
    #expect(ctx.appState.isInputPanelVisible == true)
    #expect(ctx.appState.frontmostApplication == nil)
    #expect(ctx.appState.inputText == "")
    #expect(
      ctx.appState.errorMessage == String(localized: "Target application has been terminated."))
  }

  @Test func confirmWithEmptyTextActsAsCancel() async {
    let ducker = MockVolumeDucker()
    let ctx = makeController(ducker: ducker)

    ctx.controller.showPanel()
    ctx.appState.retainLastContent("hello")
    ctx.appState.setInputText("   \n  ")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.inputText == "")
    #expect(ctx.appState.frontmostApplication == nil)
    #expect(ctx.paster.restoreClipboardCallCount == 1)
    #expect(ctx.historyStore.entries.isEmpty)
    #expect(ctx.appState.lastContent == "hello")
    #expect(ducker.restoreCallCount == 1)
  }

  @Test func confirmWhenNotVisibleIsNoop() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)
    ctx.appState.setInputText("retained")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(paster.pastedTexts.isEmpty)
    #expect(ctx.appState.inputText == "retained")
    #expect(paster.restoreClipboardCallCount == 0)
  }

  @Test func confirmWithNoTargetAppSetsError() async {
    let ctx = makeController()

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.offerScriptUndo(restoring: "before")
    ctx.appState.frontmostApplication = nil

    await ctx.controller.confirm()

    #expect(ctx.appState.lastContent == "hello")
    #expect(ctx.appState.errorMessage == String(localized: "No target application"))
    #expect(ctx.appState.isInputPanelVisible == true)
    #expect(ctx.appState.scriptUndoText == nil)
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
    #expect(paster.restoreClipboardCallCount == 0)

    paster.finishPaste()
    await confirmTask.value

    // Confirm should have succeeded — cancel was ignored
    #expect(ctx.appState.isInputPanelVisible == false)
    #expect(ctx.appState.inputText == "")
    #expect(paster.pastedTexts == ["hello"])
    #expect(ctx.appState.lastContent == "hello")
  }

  @Test func cancelCallsRestoreClipboard() {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.controller.cancel()

    #expect(paster.restoreClipboardCallCount == 1)
  }

  // MARK: - History

  @Test func confirmDoesNotRecordWhenDisabled() async {
    let paster = MockPaster()
    let ctx = makeController(paster: paster)

    ctx.appState.settings.history.isHistoryEnabled = false

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.historyStore.entries.isEmpty)
    #expect(ctx.appState.lastContent == "hello")
  }

  @Test func confirmDoesNotRecordOnPasteFailure() async {
    let paster = MockPaster()
    paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
    let ctx = makeController(paster: paster)

    ctx.controller.showPanel()
    ctx.appState.setInputText("hello")
    ctx.appState.offerScriptUndo(restoring: "before")
    ctx.appState.frontmostApplication = NSRunningApplication.current

    await ctx.controller.confirm()

    #expect(ctx.historyStore.entries.isEmpty)
    #expect(ctx.appState.lastContent == "hello")
    #expect(ctx.appState.scriptUndoText == nil)
  }
}
