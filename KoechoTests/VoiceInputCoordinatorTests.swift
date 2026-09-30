import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
@Suite(.timeLimit(.minutes(1))) struct VoiceInputCoordinatorTests {
  private func makeCoordinator(
    inputText: String = "",
    isInputPanelVisible: Bool = true
  ) -> (VoiceInputCoordinator, AppState, MockTextViewOperating, MockVoiceInputEngine) {
    let appState = makeTestAppState()
    appState.isInputPanelVisible = isInputPanelVisible
    appState.setInputText(inputText)

    let mockEngine = MockVoiceInputEngine()
    let coordinator = makeTestVoiceCoordinator(
      appState: appState,
      makeEngine: { mockEngine }
    )

    let mockTV = MockTextViewOperating()
    mockTV.string = inputText
    mockTV.finalizedString = inputText
    coordinator.textView = mockTV

    return (coordinator, appState, mockTV, mockEngine)
  }

  private func makeRestartableCoordinator(
    inputText: String = "",
    isInputPanelVisible: Bool = true,
    restartResult: Bool = true
  ) -> (VoiceInputCoordinator, AppState, MockTextViewOperating, MockRestartableVoiceInputEngine) {
    let appState = makeTestAppState()
    appState.isInputPanelVisible = isInputPanelVisible
    appState.setInputText(inputText)

    let mockEngine = MockRestartableVoiceInputEngine()
    mockEngine.restartResult = restartResult
    let coordinator = makeTestVoiceCoordinator(
      appState: appState,
      makeEngine: { mockEngine }
    )

    let mockTV = MockTextViewOperating()
    mockTV.string = inputText
    mockTV.finalizedString = inputText
    coordinator.textView = mockTV

    return (coordinator, appState, mockTV, mockEngine)
  }

  // MARK: - Engine lifecycle

  @Test func finalizedVoiceEditInvalidatesScriptUndo() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "after")
    coordinator.moveVoiceInsertionPoint(toEndOf: "after")
    appState.offerScriptUndo(restoring: "before")

    coordinator.voiceInput(didFinalize: " voice")

    #expect(appState.inputText == "after voice")
    #expect(appState.scriptUndoText == nil)
  }

  @Test func startEngineCallsEngineStart() {
    let (coordinator, _, _, mockEngine) = makeCoordinator()

    coordinator.startEngine()

    #expect(mockEngine.startCallCount == 1)
  }

  @Test func stopEngineSuppressesAutoReplacementUntilStopCompletes() async throws {
    let (coordinator, appState, _, engine) = makeCoordinator()
    appState.settings.replacement.isAutoReplacementEnabled = true
    var replacementCalls = 0
    coordinator.onAutoReplacement = { replacementCalls += 1 }
    let finishStop = AsyncStream<Void>.makeStream()
    engine.onStop = {
      for await _ in finishStop.stream { break }
    }

    let stopTask = Task { await coordinator.stopEngine() }
    defer { finishStop.continuation.finish() }
    for _ in 0..<100 where engine.stopCallCount == 0 {
      await Task.yield()
    }
    try #require(engine.stopCallCount == 1, "Engine stop request did not start")

    #expect(coordinator.isStoppingEngine)
    #expect(engine.stopCallCount == 1)
    coordinator.voiceInput(didFinalize: "first")
    #expect(appState.inputText == "first")
    #expect(replacementCalls == 0)

    finishStop.continuation.yield(())
    await stopTask.value
    #expect(!coordinator.isStoppingEngine)
    coordinator.voiceInput(didFinalize: " second")
    #expect(replacementCalls == 1)
  }

  @Test func cancelEngineCallsEngineCancel() {
    let (coordinator, _, _, mockEngine) = makeCoordinator()

    coordinator.cancelEngine()

    #expect(mockEngine.cancelCallCount == 1)
  }

  // MARK: - prepareForShow

  @Test func prepareForShowResetsState() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(3)
    coordinator.currentVoiceTarget = .prompt
    coordinator.replayState = .restartInProgress(localText: "some text")

    coordinator.prepareForShow()

    #expect(coordinator.voiceInsertionPoint == (appState.inputText as NSString).length)
    #expect(coordinator.currentVoiceTarget == .textEditor)
    #expect(coordinator.replayState == .idle)
  }

  // MARK: - switchEngine

  @Test func switchEngineSyncsAppStateInputText() async {
    let (coordinator, appState, mockTV, _) = makeCoordinator(inputText: "hello")
    appState.isInputPanelVisible = true
    mockTV.finalizedString = "hello world"
    mockTV.selectedRangeValue = NSRange(location: 11, length: 0)

    await coordinator.switchEngine()

    #expect(appState.inputText == "hello world")
    #expect(coordinator.voiceInsertionPoint == 11)
  }

  // MARK: - disableEngine

  @Test func disableEngineWaitsForStopThenClearsVolatileAndSyncsFinalizedText() async {
    let (coordinator, appState, mockTV, engine) = makeCoordinator(inputText: "old")
    mockTV.string = "confirmed draft"
    mockTV.finalizedString = "confirmed"
    mockTV.volatileRange = NSRange(location: 9, length: 6)
    coordinator.replayState = .restartInProgress(localText: "draft")

    let stopStarted = AsyncStream<Void>.makeStream()
    let finishStop = AsyncStream<Void>.makeStream()
    engine.onStop = {
      stopStarted.continuation.yield(())
      for await _ in finishStop.stream { break }
    }
    var clearedBeforeRead = false
    mockTV.onClearVolatileText = { [weak coordinator, weak appState, weak engine] in
      guard let coordinator, let appState, let engine else { return }
      #expect(engine.state == .idle)
      #expect(appState.inputText == "old")
      #expect(coordinator.replayState == .restartInProgress(localText: "draft"))
      clearedBeforeRead = true
    }
    mockTV.onReadFinalizedString = { [weak coordinator, weak appState, weak mockTV] in
      guard let coordinator, let appState, let mockTV else { return }
      #expect(clearedBeforeRead)
      #expect(mockTV.clearVolatileTextCallCount == 1)
      #expect(appState.inputText == "old")
      #expect(coordinator.replayState == .restartInProgress(localText: "draft"))
    }

    let disableTask = Task { await coordinator.disableEngine() }
    for await _ in stopStarted.stream { break }

    #expect(engine.state == .stopping)
    #expect(mockTV.clearVolatileTextCallCount == 0)
    #expect(mockTV.volatileRange != nil)
    #expect(appState.inputText == "old")
    #expect(coordinator.replayState == .restartInProgress(localText: "draft"))

    finishStop.continuation.yield(())
    await disableTask.value

    #expect(engine.stopCallCount == 1)
    #expect(clearedBeforeRead)
    #expect(mockTV.volatileRange == nil)
    #expect(appState.inputText == "confirmed")
    #expect(coordinator.replayState == .idle)
  }

  @Test func disableEngineClearsAccumulatedFinalizedText() async {
    let (coordinator, _, mockTV, _) = makeCoordinator()
    coordinator.voiceInput(didFinalize: "hello.")
    #expect(mockTV.insertFinalizedTextCalls.count == 1)

    await coordinator.disableEngine()
    coordinator.voiceInput(didFinalize: "hello.")

    #expect(mockTV.insertFinalizedTextCalls.count == 2)
    #expect(mockTV.insertFinalizedTextCalls[1].text == "hello.")
  }

  @Test func disableEngineAllowsNextTranscriberRestart() async {
    let (coordinator, _, _, engine) = makeRestartableCoordinator()
    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value
    #expect(engine.restartTranscriberCallCount == 1)

    await coordinator.disableEngine()
    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value

    #expect(engine.stopCallCount == 1)
    #expect(engine.restartTranscriberCallCount == 2)
  }

  // MARK: - resetState

  @Test func resetStateClearsReplayFlags() {
    let (coordinator, _, _, _) = makeCoordinator()
    coordinator.replayState = .suppressing(localText: "text", deadline: Date.now)

    coordinator.resetState()

    #expect(coordinator.replayState == .idle)
  }

  // MARK: - VoiceInputDelegate: didFinalize

  @Test func didFinalizeInsertsText() {
    let (coordinator, appState, mockTV, _) = makeCoordinator(inputText: "")

    coordinator.voiceInput(didFinalize: "hello")

    #expect(mockTV.insertFinalizedTextCalls.count == 1)
    #expect(mockTV.insertFinalizedTextCalls[0].text == "hello")
    #expect(mockTV.string == "hello")
    #expect(appState.inputText == "hello")
    #expect(coordinator.voiceInsertionPoint == 5)
  }

  @Test func didFinalizeSkipsWhenNotVisible() {
    let (coordinator, _, mockTV, _) = makeCoordinator(
      inputText: "",
      isInputPanelVisible: false
    )
    coordinator.voiceInput(didFinalize: "hello")

    #expect(mockTV.insertFinalizedTextCalls.isEmpty)
    #expect(mockTV.string == "")
  }

  @Test func didFinalizeCallsOnAutoReplacement() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "")
    appState.settings.replacement.isAutoReplacementEnabled = true
    var autoReplacementCalled = false
    coordinator.onAutoReplacement = { autoReplacementCalled = true }

    coordinator.voiceInput(didFinalize: "hello")

    #expect(autoReplacementCalled)
  }

  @Test func didFinalizeSkipsAutoReplacementWhenDisabled() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "")
    appState.settings.replacement.isAutoReplacementEnabled = false
    var autoReplacementCalled = false
    coordinator.onAutoReplacement = { autoReplacementCalled = true }

    coordinator.voiceInput(didFinalize: "hello")

    #expect(!autoReplacementCalled)
  }

  @Test func didFinalizeClearsPromptVolatileTextWhenTargetIsPrompt() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "")
    coordinator.currentVoiceTarget = .prompt
    appState.volatilePromptText = "hel"

    coordinator.voiceInput(didFinalize: "hello")

    #expect(appState.promptText == "hello")
    #expect(appState.volatilePromptText == "")
  }

  @Test func didUpdateVolatileSetsPromptVolatileTextWhenTargetIsPrompt() {
    let (coordinator, appState, mockTV, _) = makeCoordinator(inputText: "")
    coordinator.currentVoiceTarget = .prompt

    coordinator.voiceInput(didUpdateVolatile: "hel")

    #expect(appState.volatilePromptText == "hel")
    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  // MARK: - Replay suppression

  @Test func replayFinalizeIsSkippedInReplayContext() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(5)

    // Simulate locally finalized state with replay context
    coordinator.replayState = .suppressing(localText: "hello", deadline: Date.now + 10)

    // This should be treated as replay and skipped
    coordinator.voiceInput(didFinalize: "hello")

    // Text should not be inserted again
    #expect(mockTV.insertFinalizedTextCalls.isEmpty)
    #expect(mockTV.string == "hello")
  }

  // MARK: - VoiceInputDelegate: didUpdateVolatile

  @Test func didUpdateVolatileSetsVolatileText() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(5)

    coordinator.voiceInput(didUpdateVolatile: " world")

    #expect(mockTV.setVolatileTextCalls.count == 1)
    #expect(mockTV.setVolatileTextCalls[0].text == " world")
  }

  @Test func visibleVolatileVoiceTextInvalidatesScriptUndoBeforeFinalization() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "after")
    let textView = VoiceInputTextView()
    textView.replaceText("after")
    coordinator.textView = textView
    coordinator.moveVoiceInsertionPoint(toEndOf: "after")
    appState.offerScriptUndo(restoring: "before")

    coordinator.voiceInput(didUpdateVolatile: " voice")

    #expect(textView.string == "after voice")
    #expect(textView.volatileRange == NSRange(location: 5, length: 6))
    #expect(appState.inputText == "after")
    #expect(appState.scriptUndoText == nil)
  }

  @Test func didUpdateVolatileSuppressesReplayWithinDeadline() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .suppressing(localText: "hello", deadline: Date.now + 10)

    coordinator.voiceInput(didUpdateVolatile: "hel")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  // MARK: - Overlap stripping

  @Test func stripOverlappingPrefixReturnsOriginalForEmptyInputs() {
    let (coordinator, _, _, _) = makeCoordinator()

    #expect(coordinator.stripOverlappingPrefix("hello", accumulated: "") == "hello")
    #expect(coordinator.stripOverlappingPrefix("", accumulated: "hello") == "")
  }

  @Test func stripOverlappingPrefixRemovesLongestOverlapUpTo512Characters() {
    let (coordinator, _, _, _) = makeCoordinator()
    let overlap = "a" + String(repeating: "b", count: 511)

    let result = coordinator.stripOverlappingPrefix(
      overlap + " tail",
      accumulated: "prefix " + overlap
    )

    #expect(result == " tail")
  }

  @Test func stripOverlappingPrefixDoesNotCheckBeyond512Characters() {
    let (coordinator, _, _, _) = makeCoordinator()
    let overlap = "a" + String(repeating: "b", count: 512)
    let newText = overlap + " tail"

    let result = coordinator.stripOverlappingPrefix(
      newText,
      accumulated: "prefix " + overlap
    )

    #expect(result == newText)
  }

  @Test func stripOverlappingPrefixKeepsSingleNonPunctuationOverlap() {
    let (coordinator, _, _, _) = makeCoordinator()

    let result = coordinator.stripOverlappingPrefix(
      "apple",
      accumulated: "banana"
    )

    #expect(result == "apple")
  }

  @Test func stripOverlappingPrefixRemovesSinglePunctuationOverlap() {
    let (coordinator, _, _, _) = makeCoordinator()

    let result = coordinator.stripOverlappingPrefix(
      ". world",
      accumulated: "hello."
    )

    #expect(result == " world")
  }

  // MARK: - handleCursorMoved

  @Test func handleCursorMovedUpdatesVoiceInsertionPoint() {
    let (coordinator, _, _, _) = makeCoordinator(inputText: "hello")

    coordinator.handleCursorMoved(3)

    #expect(coordinator.voiceInsertionPoint == 3)
  }

  @Test func handleCursorMovedFinalizesVolatile() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    mockTV.volatileRange = NSRange(location: 5, length: 6)
    mockTV.string = "hello world"
    mockTV.finalizedString = "hello"
    // The mock engine exercises the generic volatile-text lifecycle.

    coordinator.handleCursorMoved(3)

    #expect(mockTV.finalizeVolatileTextCallCount == 1)
    #expect(coordinator.replayState == .restartInProgress(localText: " world"))
  }

  // MARK: - Volatile suppression during cursor move (replay state without deadline)

  @Test func didUpdateVolatileSuppressesWhenLocallyFinalizedAndNoDeadline() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .restartInProgress(localText: "world")

    coordinator.voiceInput(didUpdateVolatile: "wor")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  @Test func didUpdateVolatileClearsStateWhenDeadlineExpired() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .suppressing(localText: "world", deadline: Date.distantPast)

    coordinator.voiceInput(didUpdateVolatile: "new text")

    #expect(coordinator.replayState == .idle)
    #expect(mockTV.setVolatileTextCalls.count == 1)
  }

  @Test func handleCursorMovedThenVolatileIsSuppressed() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    mockTV.string = "hello world"
    mockTV.finalizedString = "hello"
    mockTV.volatileRange = NSRange(location: 5, length: 6)

    coordinator.handleCursorMoved(3)
    // The non-restartable mock leaves restartTranscriberIfNeeded() as a no-op.
    // This tests the restartInProgress suppression path (all volatile suppressed).
    coordinator.voiceInput(didUpdateVolatile: "replay")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  @Test func restartTranscriberSuccessBeginsReplaySuppression() async {
    let (coordinator, _, _, engine) = makeRestartableCoordinator()
    coordinator.replayState = .restartInProgress(localText: "hello")

    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value

    #expect(engine.restartTranscriberCallCount == 1)
    guard case .suppressing(let localText, let deadline) = coordinator.replayState else {
      Issue.record("Expected replay suppression after successful transcriber restart")
      return
    }
    #expect(localText == "hello")
    #expect(deadline > Date.now)
  }

  @Test func restartTranscriberFailureAllowsRetry() async {
    let (coordinator, _, _, engine) = makeRestartableCoordinator(restartResult: false)

    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value
    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value

    #expect(engine.restartTranscriberCallCount == 2)
  }

  @Test func restartTranscriberRunsOnceForConsecutiveRequests() async {
    let (coordinator, _, _, engine) = makeRestartableCoordinator()

    coordinator.handleTextChanged()
    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value

    #expect(engine.restartTranscriberCallCount == 1)
  }

  @Test func didUpdateVolatileClearsStateOnNonMatchingTextWithinDeadline() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .suppressing(localText: "hello", deadline: Date.now + 10)

    coordinator.voiceInput(didUpdateVolatile: "completely different")

    #expect(coordinator.replayState == .idle)
    #expect(mockTV.setVolatileTextCalls.count == 1)
  }

}
