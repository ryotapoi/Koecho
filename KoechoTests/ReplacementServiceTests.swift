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
    let (service, appState, _, _) = makeService(inputText: "hello")

    service.applyOrPreview()

    #expect(appState.inputText == "hello")
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
    let (service, appState, _, _) = makeService(inputText: "hello")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "goodbye", replacement: "bye")
    )

    service.applyOrPreview()

    #expect(appState.inputText == "hello")
  }

  @Test func applyOrPreviewWithEmptyText() {
    let (service, appState, _, _) = makeService(inputText: "")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )

    service.applyOrPreview()

    #expect(appState.inputText == "")
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

  @Test func applyRulesReturnsOriginalWhenNoRules() {
    let (service, _, _, _) = makeService()

    let result = service.applyRules(to: "hello")

    #expect(result == "hello")
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
  }

  // MARK: - Multiple rules

  @Test func multipleRulesChainedApplication() {
    let (service, appState, _, _) = makeService(inputText: "えーとあのー天気")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "あのー", replacement: "")
    )

    service.applyOrPreview()

    #expect(appState.inputText == "天気")
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

  // MARK: - clearPreviews

  @Test func clearPreviewsDelegatesToTextView() {
    let (service, _, mockTV, _) = makeService()

    service.clearPreviews()

    #expect(mockTV.clearReplacementPreviewsCallCount == 1)
  }
}
