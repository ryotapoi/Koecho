import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
@Suite struct ReplacementServiceTests {
  private func makeService(
    inputText: String = "",
    isInputPanelVisible: Bool = true
  ) -> (ReplacementService, AppState, MockTextViewOperating, VoiceInputCoordinator) {
    let appState = makeTestAppState()
    appState.isInputPanelVisible = isInputPanelVisible
    appState.setInputText(inputText)

    let coordinator = makeTestVoiceCoordinator(appState: appState)

    let service = ReplacementService(
      appState: appState,
      voiceCoordinator: coordinator
    )
    let mockTV = MockTextViewOperating()
    mockTV.string = inputText
    mockTV.finalizedString = inputText
    service.textView = mockTV
    return (service, appState, mockTV, coordinator)
  }

  // MARK: - applyOrPreview

  @Test func applyOrPreviewTransformsText() {
    let (service, appState, mockTV, _) = makeService(inputText: "えーと天気")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    service.applyOrPreview()

    #expect(appState.inputText == "天気")
    #expect(mockTV.replaceTextSelectingCalls.last?.text == "天気")
  }

  @Test func replacementEditInvalidatesScriptUndo() {
    let (service, appState, _, _) = makeService(inputText: "after")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "after", replacement: "changed")
    )
    appState.offerScriptUndo(restoring: "before")

    service.applyOrPreview()

    #expect(appState.inputText == "changed")
    #expect(appState.scriptUndoText == nil)
  }

  @Test func applyOrPreviewAdjustsVoiceInsertionPoint() {
    let (service, appState, _, coordinator) = makeService(inputText: "えーと天気")
    coordinator.handleCursorMoved(5)  // after "えーと天気" = 5 UTF-16 units
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    service.applyOrPreview()

    // "えーと" (3 chars) removed before insertion point, so 5 - 3 = 2
    #expect(coordinator.voiceInsertionPoint == 2)
  }

  @Test func applyOrPreviewSkipsWhenNotVisible() {
    let (service, appState, _, _) = makeService(
      inputText: "えーと天気",
      isInputPanelVisible: false
    )
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    service.applyOrPreview()

    #expect(appState.inputText == "えーと天気")
  }

  @Test func applyOrPreviewSkipsWhenNoRules() {
    let (service, appState, mockTV, _) = makeService(inputText: "hello")

    service.applyOrPreview()

    #expect(appState.inputText == "hello")
    #expect(mockTV.replaceTextSelectingCalls.isEmpty)
  }

  @Test func applyOrPreviewSkipsDuringScript() {
    let (service, appState, _, _) = makeService(inputText: "hello")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )
    appState.isRunningScript = true

    service.applyOrPreview()

    #expect(appState.inputText == "hello")
  }

  @Test func applyOrPreviewLeavesTextUnchangedWhenNoRuleMatches() {
    let (service, appState, mockTV, _) = makeService(inputText: "hello")
    appState.offerScriptUndo(restoring: "before")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "goodbye", replacement: "bye")
    )

    service.applyOrPreview()

    #expect(appState.inputText == "hello")
    #expect(appState.scriptUndoText == "before")
    #expect(mockTV.replaceTextSelectingCalls.isEmpty)
  }

  // MARK: - applyRules(to:)

  @Test func applyRulesTransformsWithoutTouchingVoiceInsertionPoint() {
    let (service, appState, _, coordinator) = makeService(inputText: "えーと天気")
    coordinator.handleCursorMoved(5)
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    let result = service.applyRules(to: "えーと天気")

    #expect(result == "天気")
    #expect(coordinator.voiceInsertionPoint == 5)  // unchanged
  }

  @Test func applyOrPreviewSuppressesWhenVolatilePresent() {
    let (service, appState, mockTV, _) = makeService(inputText: "hello")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )
    mockTV.volatileRange = NSRange(location: 5, length: 3)

    service.applyOrPreview()

    #expect(mockTV.clearReplacementPreviewsCallCount == 1)
    #expect(appState.inputText == "hello")  // no replacement applied
  }

  @Test func applyOrPreviewShowsPreviewWhenMarkedText() {
    let (service, appState, mockTV, _) = makeService(inputText: "hello")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )
    mockTV.markedText = true

    service.applyOrPreview()

    #expect(mockTV.showReplacementPreviewsCalls.count == 1)

    mockTV.string = "goodbye"
    service.applyOrPreview()

    #expect(mockTV.clearReplacementPreviewsCallCount == 1)
    #expect(mockTV.showReplacementPreviewsCalls.count == 1)
    #expect(appState.inputText == "hello")

    mockTV.string = ""
    service.applyOrPreview()

    #expect(mockTV.clearReplacementPreviewsCallCount == 2)
    #expect(mockTV.showReplacementPreviewsCalls.count == 1)
    #expect(appState.inputText == "hello")
  }

  @Test func replacementCoordinatesFeedRealTextViewAndFollowingVoice() {
    let (service, appState, _, coordinator) = makeService(inputText: "aZ")
    appState.settings.replacement.isAutoReplacementEnabled = false
    appState.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "bbbb"))
    appState.settings.replacement.addReplacementRule(ReplacementRule(pattern: "bbbb", replacement: "c"))
    let textView = VoiceInputTextView()
    textView.replaceText("aZ", selecting: NSRange(location: 1, length: 0))
    service.textView = textView
    coordinator.textView = textView
    coordinator.handleCursorMoved(1)

    service.applyOrPreview()

    #expect(appState.inputText == "cZ")
    #expect(coordinator.voiceInsertionPoint == 1)
    #expect(textView.selectedRange() == NSRange(location: 1, length: 0))
    coordinator.voiceInput(didUpdateVolatile: "voice")
    #expect(textView.string == "cvoiceZ")
    #expect(textView.volatileRange == NSRange(location: 1, length: 5))
    #expect(appState.inputText == "cZ")
    coordinator.voiceInput(didFinalize: "voice")
    #expect(textView.string == "cvoiceZ")
    #expect(textView.volatileRange == nil)
    #expect(appState.inputText == "cvoiceZ")
    #expect(coordinator.voiceInsertionPoint == 6)
  }

  @Test(arguments: [true, false])
  func unicodeReplacementFeedsSelectionAndFollowingVoice(local: Bool) {
    let (service, appState, _, coordinator) = makeService(inputText: "abZ")
    appState.settings.replacement.isAutoReplacementEnabled = false
    appState.settings.replacement.addReplacementRule(ReplacementRule(pattern: "ab", replacement: "👩‍💻"))
    let textView = VoiceInputTextView()
    textView.replaceText("abZ", selecting: NSRange(location: 1, length: 0))
    service.textView = textView
    coordinator.textView = textView
    coordinator.handleCursorMoved(1)

    if local {
      service.replaceSelection()
    } else {
      service.applyOrPreview()
    }

    #expect(appState.inputText == "👩‍💻Z")
    #expect(coordinator.voiceInsertionPoint == 5)
    #expect(textView.selectedRange() == NSRange(location: 5, length: 0))
    coordinator.voiceInput(didUpdateVolatile: "voice")
    #expect(textView.string == "👩‍💻voiceZ")
    #expect(textView.volatileRange == NSRange(location: 5, length: 5))
    coordinator.voiceInput(didFinalize: "voice")
    #expect(textView.string == "👩‍💻voiceZ")
    #expect(textView.volatileRange == nil)
    #expect(appState.inputText == "👩‍💻voiceZ")
    #expect(coordinator.voiceInsertionPoint == 10)
  }

  @Test func localUnicodeReplacementMapsBothSelectionEndpoints() {
    let (service, state, view, coordinator) = makeService(inputText: "abZ")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "ab", replacement: "😀"))
    coordinator.handleCursorMoved(1)
    view.selectedRangeValue = NSRange(location: 1, length: 1)
    service.refreshCandidates()

    view.onReplaceCandidate?([view.replacementCandidates[0]])

    #expect(state.inputText == "😀Z")
    #expect(coordinator.voiceInsertionPoint == 2)
    #expect(view.selectedRange() == NSRange(location: 2, length: 0))
  }

  @Test func deletionInsideMatchUpdatesSelectionAndVoiceTogether() {
    let (service, appState, textView, coordinator) = makeService(inputText: "abcFILLERz")
    appState.settings.replacement.addReplacementRule(ReplacementRule(pattern: "FILLER", replacement: ""))
    coordinator.handleCursorMoved(4)

    service.applyOrPreview()

    #expect(appState.inputText == "abcz")
    #expect(coordinator.voiceInsertionPoint == 3)
    #expect(textView.selectedRange() == NSRange(location: 3, length: 0))
  }

  @Test func markedChainPreviewUsesFinalContentWithoutEditingText() {
    let (service, appState, textView, coordinator) = makeService(inputText: "a b")
    appState.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "long"))
    appState.settings.replacement.addReplacementRule(ReplacementRule(pattern: "long", replacement: "x"))
    coordinator.handleCursorMoved(1)
    textView.markedText = true

    service.applyOrPreview()

    #expect(textView.showReplacementPreviewsCalls.last == [
      ReplacementMatch(range: NSRange(location: 0, length: 1), replacement: "x")
    ])
    #expect(textView.string == "a b")
    #expect(appState.inputText == "a b")
    #expect(coordinator.voiceInsertionPoint == 1)
    #expect(textView.replaceTextSelectingCalls.isEmpty)
  }

  // MARK: - addRule

  @Test(arguments: [true, false])
  func addRuleHonorsAutoReplacement(isAutomatic: Bool) {
    let (service, appState, view, _) = makeService(inputText: "hello world")
    appState.settings.replacement.isAutoReplacementEnabled = isAutomatic
    appState.pendingReplacementPattern = "hello"
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "world", replacement: "earth")
    )

    service.addRule(ReplacementRule(pattern: "hello", replacement: "bye"))

    #expect(appState.settings.replacement.replacementRules.count == 2)
    #expect(appState.pendingReplacementPattern == nil)
    #expect(appState.inputText == (isAutomatic ? "bye earth" : "hello world"))
    #expect(view.replacementCandidates.count == (isAutomatic ? 0 : 2))
  }

  @Test func settingsRefreshUpdatesCandidatesWithoutChangingText() {
    let (service, state, view, _) = makeService(inputText: "a b")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.replacementRules = [ReplacementRule(pattern: "a", replacement: "x")]
    service.refreshCandidates()
    #expect(view.replacementCandidates.first?.range == NSRange(location: 0, length: 1))
    #expect(view.replacementCandidateRules == state.settings.replacement.replacementRules)
    state.settings.replacement.replacementRules = [ReplacementRule(pattern: "b", replacement: "y")]
    service.refreshCandidates()
    #expect(view.replacementCandidates.first?.range == NSRange(location: 2, length: 1))
    #expect(view.replacementCandidateRules == state.settings.replacement.replacementRules)
    state.settings.replacement.isAutoReplacementEnabled = true
    service.refreshCandidates()
    #expect(view.replacementCandidates.isEmpty)
    state.settings.replacement.isAutoReplacementEnabled = false
    service.refreshCandidates()
    #expect(view.replacementCandidates.count == 1)
    #expect(state.inputText == "a b")
    #expect(view.string == "a b")
    #expect(view.replaceTextSelectingCalls.isEmpty)
  }

  @Test func manualCandidateChangesOnlyChosenOccurrenceAndMapsFollowingVoice() {
    let (service, state, view, coordinator) = makeService(inputText: "a aZ")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "bbbb"))
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "bbbb", replacement: "c"))
    coordinator.textView = view
    coordinator.handleCursorMoved(3)
    view.selectedRangeValue = NSRange(location: 3, length: 0)
    service.handleInput()
    #expect(state.inputText == "a aZ")
    #expect(view.replacementCandidates.count == 2)
    view.onReplaceCandidate?([view.replacementCandidates[1]])
    #expect(state.inputText == "a bbbbZ")
    #expect(view.selectedRange() == NSRange(location: 6, length: 0))
    #expect(coordinator.voiceInsertionPoint == 6)
    #expect(view.replacementCandidates == [
      ReplacementMatch(range: NSRange(location: 0, length: 1), replacement: "bbbb"),
      ReplacementMatch(range: NSRange(location: 2, length: 4), replacement: "c")])
    coordinator.voiceInput(didFinalize: "voice")
    #expect(state.inputText == "a bbbbvoiceZ")
  }

  @Test func staleCandidateActionsRejectChangedDocumentOrRules() {
    let (service, state, view, _) = makeService(inputText: "a a")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "long"))
    service.refreshCandidates()
    let action = view.onReplaceCandidate
    let match = view.replacementCandidates[0]
    state.setInputText("b a")
    view.replaceText("b a")
    action?([match])
    #expect(state.inputText == "b a")
    #expect(view.replacementCandidates.first?.range == NSRange(location: 2, length: 1))
    let nextAction = view.onReplaceCandidate
    let nextMatch = view.replacementCandidates[0]
    state.settings.replacement.replacementRules = []
    nextAction?([nextMatch])
    #expect(state.inputText == "b a")
    #expect(view.replacementCandidates.isEmpty)
  }

  @Test func mixedCandidateActionRejectsStaleMatchWithoutPartialEdit() {
    let (service, state, view, _) = makeService(inputText: "a a")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "long"))
    service.refreshCandidates()
    let valid = view.replacementCandidates[0]
    let stale = ReplacementMatch(range: view.replacementCandidates[1].range, replacement: "other")

    view.onReplaceCandidate?([valid, stale])

    #expect(state.inputText == "a a")
    #expect(view.string == "a a")
    #expect(view.replaceTextSelectingCalls.isEmpty)
    #expect(view.replacementCandidates.count == 2)
  }

  @Test func candidateActionCannotEditDuringMarkedVolatileScriptOrAutomaticMode() {
    let (service, state, view, _) = makeService(inputText: "a")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "long"))
    service.refreshCandidates()
    let action = view.onReplaceCandidate
    let match = view.replacementCandidates[0]
    view.markedText = true
    action?([match])
    #expect(state.inputText == "a")
    #expect(view.showReplacementPreviewsCalls.last == [match])
    view.markedText = false
    view.volatileRange = NSRange(location: 0, length: 1)
    action?([match])
    #expect(view.replacementCandidates.isEmpty)
    view.volatileRange = nil
    state.isRunningScript = true
    action?([match])
    state.isRunningScript = false
    state.settings.replacement.isAutoReplacementEnabled = true
    action?([match])
    #expect(state.inputText == "a")
    #expect(view.replaceTextSelectingCalls.isEmpty)
  }

  @Test func volatileStartClearsMarkedPreviewAndFinalRestoresManualCandidates() {
    let (service, state, view, coordinator) = makeService(inputText: "a")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "long"))
    coordinator.textView = view
    coordinator.onReplacementInput = { service.handleInput() }
    view.markedText = true
    service.handleInput()
    #expect(view.showReplacementPreviewsCalls.last?.count == 1)
    coordinator.voiceInput(didUpdateVolatile: "voice")
    #expect(view.clearReplacementPreviewsCallCount > 0)
    view.markedText = false
    coordinator.voiceInput(didFinalize: "voice")
    #expect(view.replacementCandidates.count == 1)
    #expect(state.inputText == "voicea")
  }

  @Test func manualDeletionMapsSelectionAndVoiceAndWholeReplaceStillChains() {
    let (service, state, view, coordinator) = makeService(inputText: "😀a aZ")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: ""))
    coordinator.handleCursorMoved(5)
    view.selectedRangeValue = NSRange(location: 5, length: 0)
    service.refreshCandidates()
    view.onReplaceCandidate?([view.replacementCandidates[0]])
    #expect(state.inputText == "😀 aZ")
    #expect(coordinator.voiceInsertionPoint == 4)
    #expect(view.selectedRange() == NSRange(location: 4, length: 0))
    #expect(view.replacementCandidates.first?.range == NSRange(location: 3, length: 1))
    service.applyOrPreview()
    #expect(state.inputText == "😀 Z")
    #expect(view.replacementCandidates.isEmpty)
  }

  @Test(arguments: [true, false])
  func selectedSnapshotMapsMultipleEditsAndNextVoiceWithoutChaining(local: Bool) {
    let (service, state, view, coordinator) = makeService(inputText: "😀a b cZ")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.replacementRules = [
      ReplacementRule(pattern: "a", replacement: "long"),
      ReplacementRule(pattern: "b", replacement: ""),
      ReplacementRule(pattern: "c", replacement: "x"),
      ReplacementRule(pattern: "long", replacement: "chain")]
    coordinator.textView = view
    coordinator.handleCursorMoved(7)
    view.selectedRangeValue = NSRange(location: 2, length: 5)
    if local { service.replaceSelection() } else { service.replaceAll() }
    #expect(state.inputText == "😀long  xZ")
    #expect(view.string == state.inputText)
    #expect(view.selectedRange() == NSRange(location: 2, length: 7))
    #expect(coordinator.voiceInsertionPoint == 9)
    #expect(view.replacementCandidates == [ReplacementMatch(range: NSRange(location: 2, length: 4), replacement: "chain")])
    coordinator.voiceInput(didFinalize: "voice")
    #expect(state.inputText == "😀long  xvoiceZ")
  }

  @Test(arguments: [false, true]) func localShortcutRejectsUncommittedText(marked: Bool) {
    let (service, state, view, coordinator) = makeService(inputText: "aZ")
    state.settings.replacement.replacementRules = [ReplacementRule(pattern: "a", replacement: "long")]
    view.selectedRangeValue = NSRange(location: 1, length: 0)
    coordinator.handleCursorMoved(1)
    view.markedText = marked
    view.volatileRange = marked ? nil : NSRange(location: 0, length: 1)
    service.replaceSelection()
    #expect(state.inputText == "aZ")
    #expect(view.selectedRange() == NSRange(location: 1, length: 0))
    #expect(coordinator.voiceInsertionPoint == 1)
  }

  @Test(arguments: ["marked", "volatile", "script", "snapshot", "hidden"])
  func wholeDocumentShortcutRejectsUnsafeEditing(reason: String) {
    let (service, state, view, coordinator) = makeService(inputText: "aZ")
    state.settings.replacement.replacementRules = [ReplacementRule(pattern: "a", replacement: "long")]
    view.selectedRangeValue = NSRange(location: 1, length: 0)
    coordinator.handleCursorMoved(1)
    switch reason {
    case "marked": view.markedText = true
    case "volatile": view.volatileRange = NSRange(location: 0, length: 1)
    case "script": state.isRunningScript = true
    case "snapshot": view.string = "a different snapshot"
    default: state.isInputPanelVisible = false
    }
    let snapshot = view.string
    service.replaceAll()
    #expect(state.inputText == "aZ")
    #expect(view.string == snapshot)
    #expect(view.selectedRange() == NSRange(location: 1, length: 0))
    #expect(coordinator.voiceInsertionPoint == 1)
  }

  @Test func localNoTargetPreservesDocumentSelectionAndVoicePoint() {
    let (service, state, view, coordinator) = makeService(inputText: "aZ")
    state.settings.replacement.replacementRules = [ReplacementRule(pattern: "a", replacement: "long")]
    view.selectedRangeValue = NSRange(location: 2, length: 0)
    coordinator.handleCursorMoved(2)
    service.replaceSelection()
    #expect(state.inputText == "aZ")
    #expect(view.string == "aZ")
    #expect(view.selectedRange() == NSRange(location: 2, length: 0))
    #expect(coordinator.voiceInsertionPoint == 2)
  }

}
