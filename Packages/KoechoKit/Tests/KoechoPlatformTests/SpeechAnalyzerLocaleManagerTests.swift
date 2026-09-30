import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
@Suite
struct SpeechAnalyzerLocaleManagerTests {
  @Test func initialState() {
    let manager = SpeechAnalyzerLocaleManager()
    #expect(manager.allLocales.isEmpty)
    #expect(manager.isLoading == true)
    #expect(manager.isDownloading == false)
    #expect(manager.downloadError == nil)
    #expect(manager.reservedLocales.isEmpty)
  }

  @Test func findNormalizedMatchExactMatch() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "en-US", displayName: "English (US)", sortKey: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: true),
      LocaleItem(
        identifier: "ja-JP", displayName: "Japanese", sortKey: "Japanese",
        normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
    ]
    let match = manager.findNormalizedMatch(for: "en-US", in: items)
    #expect(match?.identifier == "en-US")
  }

  @Test func findNormalizedMatchNormalized() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "en_US", displayName: "English (US)", sortKey: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en_US"), isReserved: true)
    ]
    let match = manager.findNormalizedMatch(for: "en-US", in: items)
    #expect(match?.identifier == "en_US")
  }

  @Test func findNormalizedMatchNoMatch() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "en-US", displayName: "English (US)", sortKey: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: true)
    ]
    let match = manager.findNormalizedMatch(for: "fr-FR", in: items)
    #expect(match == nil)
  }

  // MARK: - correctSelection

  @Test func correctSelectionWhenSelectionInAll() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "en-US", displayName: "English (US)", sortKey: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: false)
    ]
    let result = manager.correctSelection(currentSelection: "en-US", items: items)
    #expect(result == nil)
  }

  @Test func correctSelectionJaJPFallback() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "ja-JP", displayName: "Japanese", sortKey: "Japanese",
        normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
      LocaleItem(
        identifier: "fr-FR", displayName: "French", sortKey: "French",
        normalizedKey: SpeechLocale.normalizationKey("fr-FR"), isReserved: true),
    ]
    let result = manager.correctSelection(currentSelection: "de-DE", items: items)
    #expect(result == "ja-JP")
  }

  @Test func correctSelectionFirstItemFallback() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "fr-FR", displayName: "French", sortKey: "French",
        normalizedKey: SpeechLocale.normalizationKey("fr-FR"), isReserved: true),
      LocaleItem(
        identifier: "de-DE", displayName: "German", sortKey: "German",
        normalizedKey: SpeechLocale.normalizationKey("de-DE"), isReserved: true),
    ]
    let result = manager.correctSelection(currentSelection: "zh-CN", items: items)
    #expect(result == "fr-FR")
  }

  @Test func correctSelectionEmptyItems() {
    let manager = SpeechAnalyzerLocaleManager()
    let result = manager.correctSelection(currentSelection: "en-US", items: [])
    #expect(result == nil)
  }

  @Test func correctSelectionNormalizedPriorityOverJaJP() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "ja-JP", displayName: "Japanese", sortKey: "Japanese",
        normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
      LocaleItem(
        identifier: "en_US", displayName: "English (US)", sortKey: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en_US"), isReserved: true),
    ]
    let result = manager.correctSelection(currentSelection: "en-US", items: items)
    #expect(result == "en_US")
  }
}
