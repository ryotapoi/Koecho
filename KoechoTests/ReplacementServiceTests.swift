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

  @Test func addRuleAddsAndAppliesExistingRules() {
    let (service, appState, _, _) = makeService(inputText: "hello world")
    appState.pendingReplacementPattern = "hello"
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "world", replacement: "earth")
    )

    service.addRule(ReplacementRule(pattern: "hello", replacement: "bye"))

    #expect(appState.settings.replacement.replacementRules.count == 2)
    #expect(appState.pendingReplacementPattern == nil)
    #expect(appState.inputText == "bye earth")
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
    view.onReplaceCandidate?(view.replacementCandidates[1])
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
    action?(match)
    #expect(state.inputText == "b a")
    #expect(view.replacementCandidates.first?.range == NSRange(location: 2, length: 1))
    let nextAction = view.onReplaceCandidate
    let nextMatch = view.replacementCandidates[0]
    state.settings.replacement.replacementRules = []
    nextAction?(nextMatch)
    #expect(state.inputText == "b a")
    #expect(view.replacementCandidates.isEmpty)
  }

  @Test func candidateActionCannotEditDuringMarkedVolatileScriptOrAutomaticMode() {
    let (service, state, view, _) = makeService(inputText: "a")
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "long"))
    service.refreshCandidates()
    let action = view.onReplaceCandidate
    let match = view.replacementCandidates[0]
    view.markedText = true
    action?(match)
    #expect(state.inputText == "a")
    #expect(view.showReplacementPreviewsCalls.last == [match])
    view.markedText = false
    view.volatileRange = NSRange(location: 0, length: 1)
    action?(match)
    #expect(view.replacementCandidates.isEmpty)
    view.volatileRange = nil
    state.isRunningScript = true
    action?(match)
    state.isRunningScript = false
    state.settings.replacement.isAutoReplacementEnabled = true
    action?(match)
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
    view.onReplaceCandidate?(view.replacementCandidates[0])
    #expect(state.inputText == "😀 aZ")
    #expect(coordinator.voiceInsertionPoint == 4)
    #expect(view.selectedRange() == NSRange(location: 4, length: 0))
    #expect(view.replacementCandidates.first?.range == NSRange(location: 3, length: 1))
    service.applyOrPreview()
    #expect(state.inputText == "😀 Z")
    #expect(view.replacementCandidates.isEmpty)
  }

}
