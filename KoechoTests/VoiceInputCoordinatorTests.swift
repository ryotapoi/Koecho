import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
@Suite struct VoiceInputCoordinatorTests {
  private func makeCoordinator(
    inputText: String = "",
    isInputPanelVisible: Bool = true
  ) -> (VoiceInputCoordinator, AppState, MockTextViewOperating, MockVoiceInputEngine) {
    let appState = makeTestAppState()
    appState.isInputPanelVisible = isInputPanelVisible
    appState.inputText = inputText

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

  // MARK: - Engine lifecycle

  @Test func startEngineCallsEngineStart() {
    let (coordinator, _, _, mockEngine) = makeCoordinator()

    coordinator.startEngine()

    #expect(mockEngine.startCallCount == 1)
  }

  @Test func stopEngineResetsIsStoppingFlag() async {
    let (coordinator, _, _, _) = makeCoordinator()

    #expect(coordinator.isStoppingEngine == false)
    await coordinator.stopEngine()
    #expect(coordinator.isStoppingEngine == false)
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

  // MARK: - resetState

  @Test func resetStateClearsReplayFlags() {
    let (coordinator, _, _, _) = makeCoordinator()
    coordinator.replayState = .suppressing(localText: "text", deadline: Date.now)

    coordinator.resetState()

    #expect(coordinator.replayState == .idle)
  }

  // MARK: - VoiceInputDelegate: didFinalize

  @Test func didFinalizeInsertsText() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "")
    let storage = NSTextStorage(string: "")
    mockTV.textStorage = storage
    mockTV.typingAttributes = [:]

    coordinator.voiceInput(didFinalize: "hello")

    #expect(storage.string == "hello")
    #expect(coordinator.voiceInsertionPoint == 5)
  }

  @Test func didFinalizeSkipsWhenNotVisible() {
    let (coordinator, _, mockTV, _) = makeCoordinator(
      inputText: "",
      isInputPanelVisible: false
    )
    let storage = NSTextStorage(string: "")
    mockTV.textStorage = storage

    coordinator.voiceInput(didFinalize: "hello")

    #expect(storage.string == "")
  }

  @Test func didFinalizeCallsOnAutoReplacement() {
    let (coordinator, appState, mockTV, _) = makeCoordinator(inputText: "")
    appState.settings.replacement.isAutoReplacementEnabled = true
    let storage = NSTextStorage(string: "")
    mockTV.textStorage = storage
    mockTV.typingAttributes = [:]
    var autoReplacementCalled = false
    coordinator.onAutoReplacement = { autoReplacementCalled = true }

    coordinator.voiceInput(didFinalize: "hello")

    #expect(autoReplacementCalled)
  }

  @Test func didFinalizeSkipsAutoReplacementWhenDisabled() {
    let (coordinator, appState, mockTV, _) = makeCoordinator(inputText: "")
    appState.settings.replacement.isAutoReplacementEnabled = false
    let storage = NSTextStorage(string: "")
    mockTV.textStorage = storage
    mockTV.typingAttributes = [:]
    var autoReplacementCalled = false
    coordinator.onAutoReplacement = { autoReplacementCalled = true }

    coordinator.voiceInput(didFinalize: "hello")

    #expect(!autoReplacementCalled)
  }

  @Test func didFinalizeAppendsToPromptTextWhenTargetIsPrompt() {
    let (coordinator, appState, _, _) = makeCoordinator(inputText: "")
    coordinator.currentVoiceTarget = .prompt

    coordinator.voiceInput(didFinalize: "hello")

    #expect(appState.promptText == "hello")
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
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    mockTV.typingAttributes = [:]
    coordinator.handleCursorMoved(5)

    // Simulate locally finalized state with replay context
    coordinator.replayState = .suppressing(localText: "hello", deadline: Date.now + 10)

    // This should be treated as replay and skipped
    coordinator.voiceInput(didFinalize: "hello")

    // Text should not be inserted again
    #expect(storage.string == "hello")
  }

  // MARK: - VoiceInputDelegate: didUpdateVolatile

  @Test func didUpdateVolatileSetsVolatileText() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    coordinator.handleCursorMoved(5)

    coordinator.voiceInput(didUpdateVolatile: " world")

    #expect(mockTV.setVolatileTextCalls.count == 1)
    #expect(mockTV.setVolatileTextCalls[0].text == " world")
  }

  @Test func didUpdateVolatileSuppressesReplayWithinDeadline() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .suppressing(localText: "hello", deadline: Date.now + 10)

    coordinator.voiceInput(didUpdateVolatile: "hel")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  // MARK: - Overlap stripping

  @Test func didFinalizeStripsOverlappingPrefix() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "")
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    mockTV.typingAttributes = [:]
    coordinator.handleCursorMoved(5)

    // First finalize
    coordinator.voiceInput(didFinalize: "hello")

    // Second finalize with overlap
    coordinator.voiceInput(didFinalize: "hello world")

    // Should insert only " world", not "hello world"
    #expect(storage.string.hasSuffix(" world"))
  }

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

  @Test func stripLeadingDuplicatePunctuationRemovesDuplicateAtInsertionPoint() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello.")
    mockTV.textStorage = NSTextStorage(string: "hello.")

    let result = coordinator.stripLeadingDuplicatePunctuation(". world", at: 6)

    #expect(result == " world")
  }

  @Test func stripLeadingDuplicatePunctuationKeepsDuplicateNonPunctuation() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    mockTV.textStorage = NSTextStorage(string: "hello")

    let result = coordinator.stripLeadingDuplicatePunctuation("o world", at: 5)

    #expect(result == "o world")
  }

  @Test func stripLeadingDuplicatePunctuationKeepsNonDuplicatePunctuation() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello,")
    mockTV.textStorage = NSTextStorage(string: "hello,")

    let result = coordinator.stripLeadingDuplicatePunctuation(". world", at: 6)

    #expect(result == ". world")
  }

  @Test func stripLeadingDuplicatePunctuationKeepsTextAtStartAndEmptyText() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: ".")
    mockTV.textStorage = NSTextStorage(string: ".")

    #expect(coordinator.stripLeadingDuplicatePunctuation(". world", at: 0) == ". world")
    #expect(coordinator.stripLeadingDuplicatePunctuation("", at: 1) == "")
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
    // Set a non-DictationEngine by using the mock engine (which is not DictationEngine)

    coordinator.handleCursorMoved(3)

    #expect(mockTV.finalizeVolatileTextCallCount == 1)
    #expect(coordinator.replayState == .restartInProgress(localText: " world"))
  }

  // MARK: - Volatile suppression during cursor move (replay state without deadline)

  @Test func didUpdateVolatileSuppressesWhenLocallyFinalizedAndNoDeadline() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .restartInProgress(localText: "world")

    coordinator.voiceInput(didUpdateVolatile: "wor")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  @Test func didUpdateVolatileClearsStateWhenDeadlineExpired() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .suppressing(localText: "world", deadline: Date.distantPast)

    coordinator.voiceInput(didUpdateVolatile: "new text")

    #expect(coordinator.replayState == .idle)
    #expect(mockTV.setVolatileTextCalls.count == 1)
  }

  @Test func handleCursorMovedThenVolatileIsSuppressed() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    let storage = NSTextStorage(string: "hello world")
    mockTV.textStorage = storage
    mockTV.string = "hello world"
    mockTV.finalizedString = "hello"
    mockTV.volatileRange = NSRange(location: 5, length: 6)

    coordinator.handleCursorMoved(3)
    // MockEngine is not SpeechAnalyzerEngine, so restartTranscriberIfNeeded() is a no-op.
    // This tests the restartInProgress suppression path (all volatile suppressed).
    coordinator.voiceInput(didUpdateVolatile: "replay")

    #expect(mockTV.setVolatileTextCalls.isEmpty)
  }

  @Test func didUpdateVolatileClearsStateOnNonMatchingTextWithinDeadline() {
    let (coordinator, _, mockTV, _) = makeCoordinator(inputText: "hello")
    let storage = NSTextStorage(string: "hello")
    mockTV.textStorage = storage
    coordinator.handleCursorMoved(5)
    coordinator.replayState = .suppressing(localText: "hello", deadline: Date.now + 10)

    coordinator.voiceInput(didUpdateVolatile: "completely different")

    #expect(coordinator.replayState == .idle)
    #expect(mockTV.setVolatileTextCalls.count == 1)
  }

  // MARK: - didEncounterError / didUpdateStatus

  @Test func didEncounterErrorSetsErrorMessage() {
    let (coordinator, appState, _, _) = makeCoordinator()

    coordinator.voiceInput(didEncounterError: .microphoneAccessDenied)

    #expect(
      appState.errorMessage
        == String(
          localized:
            "Microphone access denied. Open System Settings > Privacy & Security > Microphone."))
  }

  @Test func didUpdateStatusSetsVoiceEngineStatus() {
    let (coordinator, appState, _, _) = makeCoordinator()

    coordinator.voiceInput(didUpdateStatus: .downloadingModel)

    #expect(appState.voiceEngineStatus == String(localized: "Downloading speech model..."))
  }

  @Test func didUpdateStatusNilClearsVoiceEngineStatus() {
    let (coordinator, appState, _, _) = makeCoordinator()
    appState.voiceEngineStatus = "something"

    coordinator.voiceInput(didUpdateStatus: nil)

    #expect(appState.voiceEngineStatus == nil)
  }
}
