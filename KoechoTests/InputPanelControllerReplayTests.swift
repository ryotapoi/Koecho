import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

// Integration tests against the real VoiceInputTextView cover selection,
// volatile finalization, and cursor movement through the panel wiring.

extension InputPanelControllerTests {
  @Test func repeatedSpeechAfterReopeningPanelIsInserted() {
    let ctx = makeController()
    ctx.controller.showPanel()
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")

    // Cancel and reopen
    ctx.controller.cancel()
    ctx.controller.showPanel()

    // The reopened panel accepts the same speech again.
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "hello")
    #expect(ctx.appState.inputText == "hello")
  }

  // MARK: - Speech after local finalization

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
    #expect(coordinator.localFinalizationState == .restarted)

    coordinator.voiceInput(didUpdateVolatile: "dear ")
    #expect(textView.volatileRange != nil)
    coordinator.voiceInput(didFinalize: "dear ")
    #expect(ctx.appState.inputText == "hello dear world again")
    #expect(coordinator.localFinalizationState == .idle)
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

  @Test func cursorMoveKeepsFollowingSpeechThroughFinalization() throws {
    let ctx = makeController()
    ctx.controller.showPanel()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller))
    let coordinator = try #require(ctx.controller.voiceCoordinator)
    coordinator.voiceInput(didFinalize: "今日は晴れです")

    textView.setSelectedRanges(
      [NSValue(range: NSRange(location: 6, length: 0))],
      affinity: .downstream, stillSelecting: false)
    coordinator.voiceInput(didUpdateVolatile: "明日も晴れです")
    #expect(textView.string == "今日は晴れで明日も晴れですす")
    coordinator.voiceInput(didFinalize: "明日も晴れです")

    #expect(textView.volatileRange == nil)
    #expect(ctx.appState.inputText == "今日は晴れで明日も晴れですす")
  }

  @Test func newFinalizeWhileLocallyFinalizedInsertsText() throws {
    let ctx = makeController()
    ctx.controller.showPanel()
    let textView = try #require(findVoiceInputTextView(in: ctx.controller), "textView not found")

    // Insert text via normal finalize first
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "こんにちは")

    ctx.controller.voiceCoordinator.voiceInput(didUpdateVolatile: "こんにちは")
    textView.finalizeVolatileText()
    textView.onVolatileFinalized?()
    ctx.controller.voiceCoordinator.localFinalizationState.finishRestart()

    // New speech after local finalization should be inserted.
    ctx.controller.voiceCoordinator.voiceInput(didFinalize: "ありがとう")
    #expect(ctx.appState.inputText.contains("ありがとう"))
    #expect(ctx.controller.voiceCoordinator.localFinalizationState == .idle)
  }
}
