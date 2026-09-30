import Testing

@testable import KoechoPlatform

@MainActor
struct AppStateTests {
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
