import AppKit
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct AppStateTests {
  @Test func lastContentIsTransientIndependentAndCopiedWithoutConsumption() throws {
    let suiteName = "last-content-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let state = AppState(settings: Settings(defaults: defaults))
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.setString("untouched", forType: .string)
    #expect(state.lastContent == nil)
    #expect(!state.copyLastContentToClipboard(using: pasteboard))
    #expect(pasteboard.string(forType: .string) == "untouched")
    state.retainLastContent("  recovered\n")
    for empty in ["", " \n\t"] { state.retainLastContent(empty) }
    state.setInputText("editing")
    state.offerScriptUndo(restoring: "before")
    state.settings.history.isHistoryEnabled = false
    for _ in 0..<2 {
      #expect(state.copyLastContentToClipboard(using: pasteboard))
      #expect(pasteboard.string(forType: .string) == "  recovered\n")
      #expect(state.lastContent == "  recovered\n")
    }
    state.retainLastContent("next")
    #expect(state.lastContent == "next")
    #expect(AppState(settings: state.settings).lastContent == nil)
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
