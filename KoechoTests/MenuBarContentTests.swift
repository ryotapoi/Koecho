import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
struct MenuBarContentTests {
  @Test func recognitionLanguageMenuVisibilityFollowsDownloadedLocaleCount() {
    guard #available(macOS 26, *) else { return }
    let appState = makeTestAppState()
    appState.settings.voiceInput.voiceInputMode = .speechAnalyzer

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

  @Test func recognitionLanguageMenuIsHiddenOutsideSpeechAnalyzerMode() {
    guard #available(macOS 26, *) else { return }
    let appState = makeTestAppState()
    appState.settings.voiceInput.voiceInputMode = .dictation

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
      sortKey: identifier,
      normalizedKey: SpeechLocale.normalizationKey(identifier),
      isReserved: true
    )
  }
}
