import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
struct MenuBarContentTests {
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
      sortKey: identifier,
      normalizedKey: SpeechLocale.normalizationKey(identifier),
      isReserved: true
    )
  }
}
