import AppKit
import Testing
@testable import Koecho

@MainActor
struct InputPanelControllerTests {
    @Test func showPanelSetsState() {
        let appState = AppState()
        let controller = InputPanelController(appState: appState)

        controller.showPanel()

        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "")
        #expect(controller.panel.isVisible)
    }

    @Test func cancelClearsState() {
        let appState = AppState()
        let controller = InputPanelController(appState: appState)

        controller.showPanel()
        appState.inputText = "some text"
        controller.cancel()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(appState.frontmostApplication == nil)
        #expect(!controller.panel.isVisible)
    }

    @Test func cancelClearsTextAfterInput() {
        let appState = AppState()
        let controller = InputPanelController(appState: appState)

        controller.showPanel()
        appState.inputText = "hello world"
        controller.cancel()

        #expect(appState.inputText == "")
    }

    @Test func showPanelTwicePreservesText() {
        let appState = AppState()
        let controller = InputPanelController(appState: appState)

        controller.showPanel()
        appState.inputText = "hello"
        controller.showPanel()

        #expect(appState.inputText == "hello")
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func cancelWhenNotVisibleIsNoop() {
        let appState = AppState()
        let controller = InputPanelController(appState: appState)

        controller.cancel()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
    }

    @Test func showCancelShowCycle() {
        let appState = AppState()
        let controller = InputPanelController(appState: appState)

        controller.showPanel()
        #expect(appState.isInputPanelVisible == true)

        controller.cancel()
        #expect(appState.isInputPanelVisible == false)

        controller.showPanel()
        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "")
        #expect(controller.panel.isVisible)
    }
}
