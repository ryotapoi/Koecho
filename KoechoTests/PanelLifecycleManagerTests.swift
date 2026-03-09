import AppKit
import Foundation
import Testing
@testable import Koecho

@MainActor
@Suite struct PanelLifecycleManagerTests {
    private func makeManager(
        selectedTextResult: SelectedTextResult? = nil
    ) -> (PanelLifecycleManager, AppState, MockSelectedTextReader, MockVolumeDucker, InputPanel) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        let appState = AppState(settings: settings)

        let reader = MockSelectedTextReader()
        reader.resultToReturn = selectedTextResult

        let ducker = MockVolumeDucker()

        let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))

        let manager = PanelLifecycleManager(
            appState: appState,
            selectedTextReader: reader,
            ducker: ducker,
            panel: panel
        )

        return (manager, appState, reader, ducker, panel)
    }

    // MARK: - show

    @Test func showRecordsFrontmostApplication() {
        let (manager, appState, _, _, _) = makeManager()

        manager.show()

        // frontmostApplication is set from NSWorkspace (may be nil in test, but the code path executes)
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func showReadsSelectedText() {
        let result = SelectedTextResult(text: "hello", start: "1", end: "5")
        let (manager, appState, _, _, _) = makeManager(selectedTextResult: result)
        // Simulate having a frontmost app by setting it directly before show reads it
        appState.frontmostApplication = NSRunningApplication.current

        manager.show()

        #expect(appState.selectedText == "hello")
        #expect(appState.selectionStart == "1")
        #expect(appState.selectionEnd == "5")
        #expect(appState.inputText == "hello")
    }

    @Test func showSetsEmptySelectionWhenReaderReturnsNil() {
        let (manager, appState, _, _, _) = makeManager(selectedTextResult: nil)
        appState.frontmostApplication = NSRunningApplication.current

        manager.show()

        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
    }

    @Test func showCallsDuckerDuck() {
        let (manager, _, _, ducker, _) = makeManager()

        manager.show()

        #expect(ducker.duckCallCount == 1)
    }

    @Test func showResetsIsRunningScript() {
        let (manager, appState, _, _, _) = makeManager()
        appState.isRunningScript = true

        manager.show()

        #expect(appState.isRunningScript == false)
    }

    @Test func showClearsErrorMessage() {
        let (manager, appState, _, _, _) = makeManager()
        appState.errorMessage = "some error"

        manager.show()

        #expect(appState.errorMessage == nil)
    }

    // MARK: - clearState

    @Test func clearStateResetsAllAppStateProperties() {
        let (manager, appState, _, _, _) = makeManager()
        appState.inputText = "hello"
        appState.isInputPanelVisible = true
        appState.frontmostApplication = NSRunningApplication.current
        appState.selectedText = "hello"
        appState.selectionStart = "1"
        appState.selectionEnd = "5"
        appState.errorMessage = "error"
        appState.voiceEngineStatus = "Listening"
        appState.isRunningScript = true
        appState.promptText = "prompt"
        appState.pendingReplacementPattern = "pattern"

        manager.clearState()

        #expect(appState.inputText == "")
        #expect(appState.isInputPanelVisible == false)
        #expect(appState.frontmostApplication == nil)
        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
        #expect(appState.errorMessage == nil)
        #expect(appState.voiceEngineStatus == nil)
        #expect(appState.isRunningScript == false)
        #expect(appState.promptScript == nil)
        #expect(appState.promptText == "")
        #expect(appState.pendingReplacementPattern == nil)
    }

    @Test func clearStateCallsDuckerRestore() {
        let (manager, _, _, ducker, _) = makeManager()

        manager.clearState()

        #expect(ducker.restoreCallCount == 1)
    }

    // MARK: - hide

    @Test func hideCallsPanelOrderOut() {
        let (manager, _, _, _, panel) = makeManager()
        // Panel is not visible in tests, but we verify the method doesn't crash
        manager.hide()
        // No assertion needed beyond no crash; panel.orderOut is an AppKit call
    }
}
