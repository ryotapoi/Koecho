import AppKit
import KoechoCore
import Testing
@testable import KoechoPlatform

@MainActor
struct AppStateTests {
    @Test func initialState() {
        let appState = AppState()
        #expect(appState.inputText == "")
        #expect(appState.isInputPanelVisible == false)
        #expect(appState.frontmostApplication == nil)
        #expect(appState.errorMessage == nil)
        #expect(appState.isRunningScript == false)
        #expect(appState.promptText == "")
        #expect(appState.promptScript == nil)
        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
    }

    @Test func selectedTextModification() {
        let appState = AppState()
        appState.selectedText = "selected"
        appState.selectionStart = "10"
        appState.selectionEnd = "18"
        #expect(appState.selectedText == "selected")
        #expect(appState.selectionStart == "10")
        #expect(appState.selectionEnd == "18")
    }

    @Test func settingsAccessible() {
        let settings = Settings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let appState = AppState(settings: settings)
        appState.settings.paste.pasteDelay = 10.0
        #expect(appState.settings.paste.pasteDelay == 10.0)
    }

    @Test func stateModification() {
        let appState = AppState()
        appState.inputText = "Hello, world!"
        #expect(appState.inputText == "Hello, world!")
        appState.isInputPanelVisible = true
        #expect(appState.isInputPanelVisible == true)
        appState.errorMessage = "Something went wrong"
        #expect(appState.errorMessage == "Something went wrong")
        appState.errorMessage = nil
        #expect(appState.errorMessage == nil)
    }
}
