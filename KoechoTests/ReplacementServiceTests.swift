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
    appState.inputText = inputText

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

  // MARK: - applyNow

  @Test func applyNowTransformsText() {
    let (service, appState, mockTV, _) = makeService(inputText: "えーと天気")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    service.applyNow()

    #expect(appState.inputText == "天気")
    #expect(mockTV.setStringCalls.last?.text == "天気")
    #expect(mockTV.setStringCalls.last?.suppressing == true)
  }

  @Test func applyNowAdjustsVoiceInsertionPoint() {
    let (service, appState, _, coordinator) = makeService(inputText: "えーと天気")
    coordinator.handleCursorMoved(5)  // after "えーと天気" = 5 UTF-16 units
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    service.applyNow()

    // "えーと" (3 chars) removed before insertion point, so 5 - 3 = 2
    #expect(coordinator.voiceInsertionPoint == 2)
  }

  @Test func applyNowSkipsWhenNotVisible() {
    let (service, appState, _, _) = makeService(
      inputText: "えーと天気",
      isInputPanelVisible: false
    )
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "えーと", replacement: "")
    )

    service.applyNow()

    #expect(appState.inputText == "えーと天気")
  }

  @Test func applyNowSkipsWhenNoRules() {
    let (service, appState, _, _) = makeService(inputText: "hello")

    service.applyNow()

    #expect(appState.inputText == "hello")
  }

  @Test func applyNowWithEmptyText() {
    let (service, appState, _, _) = makeService(inputText: "")
    appState.settings.replacement.addReplacementRule(
      ReplacementRule(pattern: "hello", replacement: "bye")
    )

    service.applyNow()

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

  // MARK: - applyOrPreview

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

    service.applyNow()

    #expect(appState.inputText == "天気")
  }

  // MARK: - addRule

  @Test func addRuleAddsAndApplies() {
    let (service, appState, _, _) = makeService(inputText: "hello world")
    appState.pendingReplacementPattern = "hello"

    service.addRule(ReplacementRule(pattern: "hello", replacement: "bye"))

    #expect(appState.settings.replacement.replacementRules.count == 1)
    #expect(appState.pendingReplacementPattern == nil)
    #expect(appState.inputText == "bye world")
  }

  // MARK: - clearPreviews

  @Test func clearPreviewsDelegatesToTextView() {
    let (service, _, mockTV, _) = makeService()

    service.clearPreviews()

    #expect(mockTV.clearReplacementPreviewsCallCount == 1)
  }
}
