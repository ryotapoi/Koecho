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
    ) -> (ReplacementService, AppState, MockTextViewOperating, UnsafeMutablePointer<Int>) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        let appState = AppState(settings: settings)
        appState.isInputPanelVisible = isInputPanelVisible
        appState.inputText = inputText

        let vipPointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        vipPointer.pointee = 0

        let service = ReplacementService(
            appState: appState,
            getVoiceInsertionPoint: { vipPointer.pointee },
            setVoiceInsertionPoint: { vipPointer.pointee = $0 }
        )
        let mockTV = MockTextViewOperating()
        mockTV.string = inputText
        mockTV.finalizedString = inputText
        service.textView = mockTV
        return (service, appState, mockTV, vipPointer)
    }

    // MARK: - applyNow

    @Test func applyNowTransformsText() {
        let (service, appState, mockTV, vipPointer) = makeService(inputText: "えーと天気")
        defer { vipPointer.deallocate() }
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        service.applyNow()

        #expect(appState.inputText == "天気")
        #expect(mockTV.setStringCalls.last?.text == "天気")
        #expect(mockTV.setStringCalls.last?.suppressing == true)
    }

    @Test func applyNowAdjustsVoiceInsertionPoint() {
        let (service, appState, _, vipPointer) = makeService(inputText: "えーと天気")
        defer { vipPointer.deallocate() }
        vipPointer.pointee = 5 // after "えーと天気" = 5 UTF-16 units
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        service.applyNow()

        // "えーと" (3 chars) removed before insertion point, so 5 - 3 = 2
        #expect(vipPointer.pointee == 2)
    }

    @Test func applyNowSkipsWhenNotVisible() {
        let (service, appState, _, vipPointer) = makeService(
            inputText: "えーと天気",
            isInputPanelVisible: false
        )
        defer { vipPointer.deallocate() }
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        service.applyNow()

        #expect(appState.inputText == "えーと天気")
    }

    @Test func applyNowSkipsWhenNoRules() {
        let (service, appState, _, vipPointer) = makeService(inputText: "hello")
        defer { vipPointer.deallocate() }

        service.applyNow()

        #expect(appState.inputText == "hello")
    }

    @Test func applyNowWithEmptyText() {
        let (service, appState, _, vipPointer) = makeService(inputText: "")
        defer { vipPointer.deallocate() }
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )

        service.applyNow()

        #expect(appState.inputText == "")
    }

    // MARK: - applyRules(to:)

    @Test func applyRulesTransformsWithoutTouchingVoiceInsertionPoint() {
        let (service, appState, _, vipPointer) = makeService(inputText: "えーと天気")
        defer { vipPointer.deallocate() }
        vipPointer.pointee = 5
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "えーと", replacement: "")
        )

        let result = service.applyRules(to: "えーと天気")

        #expect(result == "天気")
        #expect(vipPointer.pointee == 5) // unchanged
    }

    @Test func applyRulesReturnsOriginalWhenNoRules() {
        let (service, _, _, vipPointer) = makeService()
        defer { vipPointer.deallocate() }

        let result = service.applyRules(to: "hello")

        #expect(result == "hello")
    }

    // MARK: - applyOrPreview

    @Test func applyOrPreviewSuppressesWhenVolatilePresent() {
        let (service, appState, mockTV, vipPointer) = makeService(inputText: "hello")
        defer { vipPointer.deallocate() }
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )
        mockTV.volatileRange = NSRange(location: 5, length: 3)

        service.applyOrPreview()

        #expect(mockTV.clearReplacementPreviewsCallCount == 1)
        #expect(appState.inputText == "hello") // no replacement applied
    }

    @Test func applyOrPreviewShowsPreviewWhenMarkedText() {
        let (service, appState, mockTV, vipPointer) = makeService(inputText: "hello")
        defer { vipPointer.deallocate() }
        appState.settings.replacement.addReplacementRule(
            ReplacementRule(pattern: "hello", replacement: "bye")
        )
        mockTV.markedText = true

        service.applyOrPreview()

        #expect(mockTV.showReplacementPreviewsCalls.count == 1)
    }

    // MARK: - Multiple rules

    @Test func multipleRulesChainedApplication() {
        let (service, appState, _, vipPointer) = makeService(inputText: "えーとあのー天気")
        defer { vipPointer.deallocate() }
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
        let (service, appState, _, vipPointer) = makeService(inputText: "hello world")
        defer { vipPointer.deallocate() }
        appState.pendingReplacementPattern = "hello"

        service.addRule(ReplacementRule(pattern: "hello", replacement: "bye"))

        #expect(appState.settings.replacement.replacementRules.count == 1)
        #expect(appState.pendingReplacementPattern == nil)
        #expect(appState.inputText == "bye world")
    }

    // MARK: - clearPreviews

    @Test func clearPreviewsDelegatesToTextView() {
        let (service, _, mockTV, vipPointer) = makeService()
        defer { vipPointer.deallocate() }

        service.clearPreviews()

        #expect(mockTV.clearReplacementPreviewsCallCount == 1)
    }
}
