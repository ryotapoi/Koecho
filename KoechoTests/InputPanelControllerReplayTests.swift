import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// Integration tests against the real VoiceInputTextView cover selection,
// volatile finalization, and cursor movement through the panel wiring.

extension InputPanelControllerTests {
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

  // MARK: - Replay Volatile Suppression

  @Test func completedMouseSelectionFinalizesVolatileAndMovesFollowingSpeech() async throws {
    let engine = MockRestartableVoiceInputEngine()
    let ctx = makeController(makeEngine: { engine })
    ctx.controller.showPanel()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller), "textView not found")
    let coordinator = try #require(ctx.controller.voiceCoordinator)
    coordinator.voiceInput(didFinalize: "hello world")
    coordinator.voiceInput(didUpdateVolatile: " again")
    #expect(textView.volatileRange != nil)

    let selection = NSRange(location: 6, length: 0)
    textView.setSelectedRanges(
      [NSValue(range: selection)], affinity: .downstream, stillSelecting: true)
    #expect(textView.volatileRange != nil)
    textView.setSelectedRanges(
      [NSValue(range: selection)], affinity: .downstream, stillSelecting: false)

    #expect(textView.volatileRange == nil)
    #expect(ctx.appState.inputText == "hello world again")
    #expect(textView.selectedRange() == selection)
    #expect(coordinator.voiceInsertionPoint == 6)
    await coordinator.restartTranscriberTask?.value
    #expect(engine.restartTranscriberCallCount == 1)
    guard case .suppressing = coordinator.replayState else {
      Issue.record("Expected replay suppression after cursor-triggered restart")
      return
    }

    coordinator.voiceInput(didUpdateVolatile: " again")
    #expect(textView.volatileRange == nil)
    coordinator.voiceInput(didFinalize: " again")
    #expect(ctx.appState.inputText == "hello world again")
    #expect(coordinator.replayState == .idle)
    coordinator.voiceInput(didFinalize: " again")
    #expect(ctx.appState.inputText == "hello world again")
    coordinator.voiceInput(didUpdateVolatile: "dear ")
    #expect(textView.volatileRange != nil)
    coordinator.voiceInput(didFinalize: "dear ")
    #expect(ctx.appState.inputText == "hello dear world again")
  }

  @Test func completedSelectionKeepsCaretThroughVolatileAutoReplacement() throws {
    let ctx = makeController()
    ctx.controller.showPanel()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller), "textView not found")
    let coordinator = try #require(ctx.controller.voiceCoordinator)
    coordinator.voiceInput(didFinalize: "hello world")
    coordinator.voiceInput(didUpdateVolatile: " again")
    ctx.appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "hi")
    )

    textView.setSelectedRanges(
      [NSValue(range: NSRange(location: 6, length: 0))],
      affinity: .downstream,
      stillSelecting: false
    )

    #expect(textView.string == "hi world again")
    #expect(textView.selectedRange() == NSRange(location: 3, length: 0))
    #expect(coordinator.voiceInsertionPoint == 3)
    coordinator.voiceInput(didFinalize: "dear ")
    #expect(ctx.appState.inputText == "hi dear world again")
  }

  @Test func newFinalizeWhileLocallyFinalizedInsertsText() throws {
    let ctx = makeController()
    ctx.controller.showPanel()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller), "textView not found")

    // Insert text via normal finalize first
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "こんにちは")
    textView.finalizeVolatileText()
    textView.onVolatileFinalized?("こんにちは")
    ctx.controller.voiceCoordinator.replayState.beginSuppression(deadline: Date.now + 10)

    // New speech finalize with no overlap — should be inserted
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "ありがとう")
    #expect(ctx.appState.inputText.contains("ありがとう"))
    #expect(ctx.controller.voiceCoordinator.replayState == .idle)
  }
}
