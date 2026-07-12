import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

private let supportsSpeechAnalyzer: Bool = {
  if #available(macOS 26, *) {
    return true
  }
  return false
}()

@MainActor
struct MenuBarContentTests {
  @Test(.enabled(if: supportsSpeechAnalyzer, "Requires macOS 26 or later"))
  func recognitionLanguageMenuVisibilityFollowsDownloadedLocaleCount() {
    if #available(macOS 26, *) {
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
  }

  @Test(.enabled(if: supportsSpeechAnalyzer, "Requires macOS 26 or later"))
  func recognitionLanguageMenuIsHiddenOutsideSpeechAnalyzerMode() {
    if #available(macOS 26, *) {
      let appState = makeTestAppState()
      appState.settings.voiceInput.voiceInputMode = .dictation

      #expect(
        !MenuBarContent.shouldShowRecognitionLanguageMenu(
          appState: appState,
          downloadedLocales: [makeLocaleItem("ja-JP"), makeLocaleItem("en-US")]
        )
      )
    }
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
