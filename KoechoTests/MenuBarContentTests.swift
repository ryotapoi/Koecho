import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
struct MenuBarContentTests {
  @Test func unifiedCopyPrefersTransientContentAndFallsBackToCurrentHistory() {
    let appState = makeTestAppState()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = HistoryStore(directoryURL: directory)
    let menu = MenuBarContent(
      appState: appState, historyStore: history, downloadedLocales: [],
      onTogglePanel: {}, onSwitchLanguage: { _ in })
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.setString("untouched", forType: .string)
    #expect(menu.contentToCopy == nil)
    #expect(!menu.copyLastContentToClipboard(using: pasteboard))
    #expect(pasteboard.string(forType: .string) == "untouched")

    history.add(text: "history", settings: appState.settings.history)
    #expect(menu.contentToCopy == "history")
    #expect(menu.copyLastContentToClipboard(using: pasteboard))
    #expect(pasteboard.string(forType: .string) == "history")
    #expect(appState.lastContent == nil)
    history.add(text: "new history", settings: appState.settings.history)
    #expect(menu.contentToCopy == "new history")
    #expect(history.clear())
    #expect(menu.contentToCopy == nil)

    history.add(text: "history", settings: appState.settings.history)
    appState.retainLastContent(" cancelled\n")
    for _ in 0..<2 {
      #expect(menu.contentToCopy == " cancelled\n")
      #expect(menu.copyLastContentToClipboard(using: pasteboard))
      #expect(pasteboard.string(forType: .string) == " cancelled\n")
    }
    #expect(history.clear())
    #expect(menu.contentToCopy == " cancelled\n")
    #expect(appState.lastContent == " cancelled\n")
  }

  @Test
  func recognitionLanguageMenuVisibilityFollowsDownloadedLocaleCount() {
    let appState = makeTestAppState()
    appState.settings.voiceInput.isVoiceInputEnabled = true

    #expect(
      !MenuBarContent.shouldShowRecognitionLanguageMenu(
        appState: appState,
        downloadedLocales: [makeLocaleItem("ja-JP")]
      )
    )
    #expect(
      MenuBarContent.shouldShowRecognitionLanguageMenu(
        appState: appState,
        downloadedLocales: [makeLocaleItem("ja-JP"), makeLocaleItem("en-US")]
      )
    )
  }

  @Test
  func recognitionLanguageMenuIsHiddenWhenVoiceInputIsDisabled() {
    let appState = makeTestAppState()
    appState.settings.voiceInput.isVoiceInputEnabled = false

    #expect(
      !MenuBarContent.shouldShowRecognitionLanguageMenu(
        appState: appState,
        downloadedLocales: [makeLocaleItem("ja-JP"), makeLocaleItem("en-US")]
      )
    )
  }

  private func makeLocaleItem(_ identifier: String) -> LocaleItem {
    LocaleItem(
      identifier: identifier,
      displayName: identifier,
      normalizedKey: SpeechLocale.normalizationKey(identifier),
      isReserved: true
    )
  }
}
