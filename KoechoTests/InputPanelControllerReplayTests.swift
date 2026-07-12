import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// Integration tests against the real VoiceInputTextView: they cover the
// onVolatileFinalized wiring and actual volatileRange behavior, which the
// coordinator unit tests (MockTextViewOperating) cannot.

// MARK: - SpeechAnalyzer Overlap Removal

extension InputPanelControllerTests {
  @Test func overlapRemovalFullDuplicate() {
    let ctx = makeController()
    ctx.controller.showPanel()

    // Simulate first finalize: "なんですか？"
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "なんですか？")
    let firstText = ctx.appState.inputText

    // Simulate second finalize with overlap: "なんですか？こんにちは。"
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "なんですか？こんにちは。")

    // Only "こんにちは。" should be added
    #expect(ctx.appState.inputText == firstText + "こんにちは。")
  }

  @Test func overlapRemovalPartialPunctuation() {
    let ctx = makeController()
    ctx.controller.showPanel()

    // Simulate finalize ending with punctuation
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello.")

    // Next finalize starts with the same punctuation
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: ".world")

    // The overlapping "." should be removed
    #expect(ctx.appState.inputText == "hello.world")
  }

  @Test func overlapRemovalNoOverlap() {
    let ctx = makeController()
    ctx.controller.showPanel()

    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: " world")

    #expect(ctx.appState.inputText == "hello world")
  }

  @Test func overlapRemovalCompleteDuplicate() {
    let ctx = makeController()
    ctx.controller.showPanel()

    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")
    // Complete duplicate — should produce empty after stripping
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")

    #expect(ctx.appState.inputText == "hello")
  }

  @Test func overlapRemovalSingleNonPunctuationNotStripped() {
    let ctx = makeController()
    ctx.controller.showPanel()

    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "あ")
    // Single char non-punctuation overlap should NOT be stripped
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "あいう")

    #expect(ctx.appState.inputText == "ああいう")
  }

  @Test func overlapRemovalResetOnShowPanel() {
    let ctx = makeController()
    ctx.controller.showPanel()
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")

    // Cancel and reopen
    ctx.controller.cancel()
    ctx.controller.showPanel()

    // After reopen, accumulated should be reset — no stripping
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")
    #expect(ctx.appState.inputText == "hello")
  }

  @Test func overlapRemovalResetOnSwitchEngine() async {
    let ctx = makeController()
    ctx.controller.showPanel()
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")

    await ctx.controller.switchEngine()

    // After switch, accumulated should be reset — no stripping
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")

    // inputText should contain "hello" from after switch (first "hello" was cleared by switchEngine reading textView)
    #expect(ctx.appState.inputText.contains("hello"))
  }

  // MARK: - Replay Volatile Suppression

  private func findTextView(in controller: InputPanelController) -> VoiceInputTextView? {
    func find(in view: NSView) -> VoiceInputTextView? {
      if let tv = view as? VoiceInputTextView { return tv }
      for sub in view.subviews {
        if let found = find(in: sub) { return found }
      }
      return nil
    }
    return controller.panel.contentView.flatMap { find(in: $0) }
  }

  /// Simulate local finalization: set volatile text, finalize it, trigger onVolatileFinalized.
  /// Pass `suppressUntil` to also simulate the transcriber restart completing,
  /// which opens the replay suppression window.
  private func simulateLocalFinalize(
    controller: InputPanelController,
    textView: VoiceInputTextView,
    text: String,
    suppressUntil: Date? = nil
  ) {
    controller.voiceCoordinator.voiceInput(didUpdateVolatile: text)
    textView.finalizeVolatileText()
    textView.onVolatileFinalized?(text)
    if let suppressUntil {
      controller.voiceCoordinator.replayState.beginSuppression(deadline: suppressUntil)
    }
  }

  @Test func replayVolatileSuppressedDuringTimeWindow() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now + 10)
    let textAfterFinalize = ctx.appState.inputText

    // Replay volatile "こん" — should be suppressed during time window
    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "こん")
    #expect(textView.volatileRange == nil)
    #expect(ctx.appState.inputText == textAfterFinalize)
  }

  @Test func volatileDisplayedAfterDeadlineExpires() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // Deadline in the past — expired
    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now - 1)

    // New volatile after deadline expired — should be displayed
    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "あ")
    #expect(textView.volatileRange != nil)
    // Replay state should be cleared
    #expect(ctx.controller.voiceCoordinator.replayState == .idle)
  }

  @Test func replayFinalizeSkippedByExactMatch() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // Insert text via normal finalize first
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")
    let textAfterFirstFinalize = ctx.appState.inputText

    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now + 10)

    // Replay finalize — exact match with suppressed local text → skipped
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")
    #expect(ctx.appState.inputText == textAfterFirstFinalize)
    #expect(ctx.controller.voiceCoordinator.replayState == .idle)
  }

  @Test func replayFinalizeClearsDeadline() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // Insert text via normal finalize first
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now + 10)

    // Replay finalize — clears replay state
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")
    #expect(ctx.controller.voiceCoordinator.replayState == .idle)

    // Next volatile should be displayed (deadline cleared)
    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "あ")
    #expect(textView.volatileRange != nil)
  }

  @Test func newFinalizeWhileLocallyFinalizedInsertsText() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // Insert text via normal finalize first
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now + 10)

    // New speech finalize with no overlap — should be inserted
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "ありがとう")
    #expect(ctx.appState.inputText.contains("ありがとう"))
    #expect(ctx.controller.voiceCoordinator.replayState == .idle)
  }

  @Test func newInputAfterReplay() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // Insert text via normal finalize first
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    // Local finalize (e.g. user presses Enter)
    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now + 10)

    // Replay finalize — clears flags
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    // New volatile should now be displayed
    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "あ")
    #expect(textView.volatileRange != nil)

    // New finalize should insert text
    let textBeforeFinalize = ctx.appState.inputText
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "ありがとう")
    #expect(ctx.appState.inputText != textBeforeFinalize)
    #expect(ctx.appState.inputText.contains("ありがとう"))
  }

  @Test func sameTextReSpokenAfterReplay() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // Insert text via normal finalize first so accumulatedFinalizedText is set
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")
    let textAfterFirstFinalize = ctx.appState.inputText

    // Now simulate local finalize (as if user typed Enter to restart transcriber)
    simulateLocalFinalize(
      controller: ctx.controller, textView: textView, text: "こんにちは",
      suppressUntil: Date.now + 10)

    // Replay finalize — clears flags
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    // Same text finalized again — stripOverlappingPrefix removes it
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")
    #expect(ctx.appState.inputText == textAfterFirstFinalize)
  }

  @Test func volatileDisplayedWithoutDeadline() {
    let ctx = makeController()
    ctx.controller.showPanel()
    guard let textView = findTextView(in: ctx.controller) else {
      Issue.record("textView not found")
      return
    }

    // No simulateLocalFinalize, no deadline — initial state
    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "あ")
    #expect(textView.volatileRange != nil)
  }
}
