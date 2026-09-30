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
  }

  @Test func scriptUndoIsSingleUseAndInvalidatedOnlyByChangedText() {
    let appState = AppState()
    appState.setInputText("before")
    appState.setInputText("after")
    appState.offerScriptUndo(restoring: "before")

    appState.setInputText("after")
    #expect(appState.scriptUndoText == "before")
    #expect(appState.consumeScriptUndo() == "before")
    #expect(appState.inputText == "before")
    #expect(appState.consumeScriptUndo() == nil)

    appState.offerScriptUndo(restoring: "before")
    appState.setInputText("edited")
    #expect(appState.scriptUndoText == nil)
  }
}
