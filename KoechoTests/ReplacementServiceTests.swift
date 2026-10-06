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

}
