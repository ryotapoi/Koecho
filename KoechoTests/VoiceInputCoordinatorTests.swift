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
    coordinator.onReplacementInput = { replacementCalls += 1 }
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
    coordinator.localFinalizationState = .awaitingRestart

    coordinator.prepareForShow()

    #expect(coordinator.voiceInsertionPoint == (appState.inputText as NSString).length)
    #expect(coordinator.currentVoiceTarget == .textEditor)
    #expect(coordinator.localFinalizationState == .idle)
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

  @Test func reenabledSessionSurvivesPreviousDisableCompletion() async {
    let suiteName = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let appState = AppState(settings: Settings(defaults: defaults))
    appState.isInputPanelVisible = true
    appState.setInputText("base")
    let oldEngine = MockVoiceInputEngine()
    let newEngine = MockVoiceInputEngine()
    var isInitialEngine = true
    let coordinator = makeTestVoiceCoordinator(appState: appState) {
      defer { isInitialEngine = false }
      return isInitialEngine ? oldEngine : newEngine
    }
    let textView = VoiceInputTextView()
    textView.replaceText("base", selecting: NSRange(location: 4, length: 0))
    coordinator.textView = textView
    coordinator.startEngine()

    let stopStarted = AsyncStream<Void>.makeStream()
    let finishStop = AsyncStream<Void>.makeStream()
    defer {
      stopStarted.continuation.finish()
      finishStop.continuation.finish()
    }
    var isFirstStop = true
    oldEngine.onStop = {
      // SpeechAnalyzerEngine returns immediately when stop is already in progress.
      guard isFirstStop else { return }
      isFirstStop = false
      stopStarted.continuation.yield(())
      for await _ in finishStop.stream { break }
    }

    appState.settings.voiceInput.isVoiceInputEnabled = false
    let disableTask = Task { await coordinator.disableEngine() }
    for await _ in stopStarted.stream { break }
    appState.settings.voiceInput.isVoiceInputEnabled = true
    await coordinator.switchEngine()

    #expect(newEngine.state == .listening)
    newEngine.delegate?.voiceInput(didFinalize: " new")
    newEngine.delegate?.voiceInput(didUpdateVolatile: " draft")
    coordinator.recordLocalFinalization()
    let selection = textView.selectedRange()
    let insertionPoint = coordinator.voiceInsertionPoint
    #expect(textView.string == "base new draft")
    #expect(textView.volatileRange == NSRange(location: 8, length: 6))
    #expect(appState.inputText == "base new")
    #expect(coordinator.localFinalizationState == .awaitingRestart)

    finishStop.continuation.yield(())
    await disableTask.value

    #expect(textView.string == "base new draft")
    #expect(textView.volatileRange == NSRange(location: 8, length: 6))
    #expect(appState.inputText == "base new")
    #expect(coordinator.localFinalizationState == .awaitingRestart)
    #expect(textView.selectedRange() == selection)
    #expect(coordinator.voiceInsertionPoint == insertionPoint)
    #expect(newEngine.state == .listening)
    newEngine.delegate?.voiceInput(didFinalize: " next")
    #expect(textView.string == "base new next")
    #expect(appState.inputText == "base new next")
  }

  @Test func disableEngineWaitsForStopThenClearsVolatileAndSyncsFinalizedText() async {
    let (coordinator, appState, mockTV, engine) = makeCoordinator(inputText: "old")
    mockTV.string = "confirmed draft"
    mockTV.finalizedString = "confirmed"
    mockTV.volatileRange = NSRange(location: 9, length: 6)
    coordinator.localFinalizationState = .awaitingRestart

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
      #expect(coordinator.localFinalizationState == .awaitingRestart)
      clearedBeforeRead = true
    }
    mockTV.onReadFinalizedString = { [weak coordinator, weak appState, weak mockTV] in
      guard let coordinator, let appState, let mockTV else { return }
      #expect(clearedBeforeRead)
      #expect(mockTV.clearVolatileTextCallCount == 1)
      #expect(appState.inputText == "old")
      #expect(coordinator.localFinalizationState == .awaitingRestart)
    }

    let disableTask = Task { await coordinator.disableEngine() }
    for await _ in stopStarted.stream { break }

    #expect(engine.state == .stopping)
    #expect(mockTV.clearVolatileTextCallCount == 0)
    #expect(mockTV.volatileRange != nil)
    #expect(appState.inputText == "old")
    #expect(coordinator.localFinalizationState == .awaitingRestart)

    finishStop.continuation.yield(())
    await disableTask.value

    #expect(engine.stopCallCount == 1)
    #expect(clearedBeforeRead)
    #expect(mockTV.volatileRange == nil)
    #expect(appState.inputText == "confirmed")
    #expect(coordinator.localFinalizationState == .idle)
  }

  @Test func disableEnginePreservesFollowingRepeatedSpeech() async {
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

  @Test func resetStateClearsLocalFinalization() {
    let (coordinator, _, _, _) = makeCoordinator()
    coordinator.localFinalizationState = .restarted

    coordinator.resetState()

    #expect(coordinator.localFinalizationState == .idle)
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

  @Test func didFinalizeUpdatesReplacementInput() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "")
    appState.settings.replacement.isAutoReplacementEnabled = true
    var autoReplacementCalled = false
    coordinator.onReplacementInput = { autoReplacementCalled = true }

    coordinator.voiceInput(didFinalize: "hello")

    #expect(autoReplacementCalled)
  }

  @Test func didFinalizeUpdatesCandidatesWhenAutoReplacementDisabled() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "")
    appState.settings.replacement.isAutoReplacementEnabled = false
    var autoReplacementCalled = false
    coordinator.onReplacementInput = { autoReplacementCalled = true }

    coordinator.voiceInput(didFinalize: "hello")

    #expect(autoReplacementCalled)
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

  @Test func consecutiveFinalResultsPreserveRepeatedSpeech() {
    let (coordinator, appState, _, _) = makeCoordinator()

    coordinator.voiceInput(didFinalize: "そうです")
    coordinator.voiceInput(didFinalize: "そうです")

    #expect(appState.inputText == "そうですそうです")
  }

  @Test func repeatedFinalAfterLocalFinalizationIsInserted() async {
    let (coordinator, appState, mockTV, _) = makeRestartableCoordinator()
    mockTV.string = "そうです"
    mockTV.volatileRange = NSRange(location: 0, length: 4)
    coordinator.handleCursorMoved(4)
    await coordinator.restartTranscriberTask?.value

    coordinator.voiceInput(didFinalize: "そうです")

    #expect(appState.inputText == "そうですそうです")
    #expect(coordinator.localFinalizationState == .idle)
  }

  // MARK: - VoiceInputDelegate: didUpdateVolatile

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

  // MARK: - handleCursorMoved

  @Test func handleCursorMovedFinalizesVolatile() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    mockTV.volatileRange = NSRange(location: 5, length: 6)
    mockTV.string = "hello world"
    mockTV.finalizedString = "hello"
    // The mock engine exercises the generic volatile-text lifecycle.

    coordinator.handleCursorMoved(3)

    #expect(mockTV.finalizeVolatileTextCallCount == 1)
    #expect(coordinator.localFinalizationState == .awaitingRestart)
  }

  // MARK: - Volatile updates around a transcriber restart

  @Test func handleCursorMovedThenVolatileIsSuppressed() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    mockTV.string = "hello world"
    mockTV.finalizedString = "hello"
    mockTV.volatileRange = NSRange(location: 5, length: 6)

    coordinator.handleCursorMoved(3)
    // The non-restartable mock leaves restartTranscriberIfNeeded() as a no-op.
    // All volatile updates wait for the restart to finish.
    coordinator.voiceInput(didUpdateVolatile: "replay")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  @Test func restartTranscriberSuccessAllowsRepeatedVolatileSpeech() async {
    let (coordinator, _, mockTV, engine) = makeRestartableCoordinator()
    mockTV.string = "hello"
    mockTV.volatileRange = NSRange(location: 0, length: 5)
    coordinator.handleCursorMoved(5)
    await coordinator.restartTranscriberTask?.value

    #expect(engine.restartTranscriberCallCount == 1)
    #expect(coordinator.localFinalizationState == .restarted)
    coordinator.voiceInput(didUpdateVolatile: "hello")
    #expect(mockTV.setVolatileTextCalls.count == 1)
    #expect(coordinator.localFinalizationState == .idle)
  }

  @Test func finalDuringRestartIsInsertedAndCompletionDoesNotRestoreWaiting() async {
    let (coordinator, appState, _, engine) = makeRestartableCoordinator()
    let started = AsyncStream<Void>.makeStream()
    let finish = AsyncStream<Void>.makeStream()
    engine.onRestart = {
      started.continuation.yield(())
      for await _ in finish.stream { break }
    }
    coordinator.recordLocalFinalization()
    coordinator.handleTextChanged()
    for await _ in started.stream { break }

    coordinator.voiceInput(didFinalize: "new speech")
    #expect(appState.inputText == "new speech")
    #expect(coordinator.localFinalizationState == .idle)
    finish.continuation.yield(())
    await coordinator.restartTranscriberTask?.value
    #expect(coordinator.localFinalizationState == .idle)
  }

  @Test func localFinalizationAfterRestartDoesNotSuppressNewVolatile() async {
    let (coordinator, _, mockTV, _) = makeRestartableCoordinator()
    coordinator.recordLocalFinalization()
    coordinator.handleTextChanged()
    await coordinator.restartTranscriberTask?.value
    coordinator.recordLocalFinalization()

    coordinator.voiceInput(didUpdateVolatile: "new text")

    #expect(mockTV.setVolatileTextCalls.count == 1)
    #expect(coordinator.localFinalizationState == .idle)
  }

  @Test(arguments: [false, true])
  func resetIgnoresDelayedRestartCompletion(cancelEngine: Bool) async {
    let (coordinator, _, mockTV, engine) = makeRestartableCoordinator()
    let started = AsyncStream<Void>.makeStream()
    let finish = AsyncStream<Void>.makeStream()
    engine.onRestart = {
      started.continuation.yield(())
      for await _ in finish.stream { break }
    }
    coordinator.recordLocalFinalization()
    coordinator.handleTextChanged()
    let restart = coordinator.restartTranscriberTask
    for await _ in started.stream { break }
    if cancelEngine { coordinator.cancelEngine() }
    coordinator.resetState()
    // A new local finalization must not be released by the old completion.
    coordinator.recordLocalFinalization()
    finish.continuation.yield(())
    await restart?.value

    #expect(coordinator.localFinalizationState == .awaitingRestart)
    coordinator.voiceInput(didUpdateVolatile: "old result")
    #expect(mockTV.setVolatileTextCalls.isEmpty)
    coordinator.resetState()
    coordinator.voiceInput(didUpdateVolatile: "new text")
    #expect(mockTV.setVolatileTextCalls.count == 1)
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

}
