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

  @Test func nextSelectionUsesMenuOrderAndWrapsWithNormalizedIdentifiers() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = ["fr-FR", "ja-JP", "en_US"].map {
      LocaleItem(identifier: $0, displayName: $0,
        normalizedKey: SpeechLocale.normalizationKey($0), isReserved: true)
    }
    #expect(manager.nextSelection(currentSelection: "fr-FR", items: items) == "ja-JP")
    #expect(manager.nextSelection(currentSelection: "ja-JP", items: items) == "en_US")
    #expect(manager.nextSelection(currentSelection: "en-US", items: items) == "fr-FR")
    #expect(manager.nextSelection(currentSelection: "de-DE", items: items) == "ja-JP")
    #expect(manager.nextSelection(currentSelection: "de-DE", items: [items[0]]) == "fr-FR")
    #expect(manager.nextSelection(currentSelection: "fr_FR", items: [items[0]]) == "fr-FR")
    #expect(manager.nextSelection(currentSelection: "en-US", items: []) == nil)
  }

  // MARK: - correctSelection

  @Test func correctSelectionWhenSelectionInAll() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "en-US", displayName: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: false)
    ]
    let result = manager.correctSelection(currentSelection: "en-US", items: items)
    #expect(result == nil)
  }

  @Test func correctSelectionJaJPFallback() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "fr-FR", displayName: "French",
        normalizedKey: SpeechLocale.normalizationKey("fr-FR"), isReserved: true),
      LocaleItem(
        identifier: "ja-JP", displayName: "Japanese",
        normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
    ]
    let result = manager.correctSelection(currentSelection: "de-DE", items: items)
    #expect(result == "ja-JP")
  }

  @Test func correctSelectionFirstItemFallback() {
    let manager = SpeechAnalyzerLocaleManager()
    let items = [
      LocaleItem(
        identifier: "fr-FR", displayName: "French",
        normalizedKey: SpeechLocale.normalizationKey("fr-FR"), isReserved: true),
      LocaleItem(
        identifier: "de-DE", displayName: "German",
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
        identifier: "ja-JP", displayName: "Japanese",
        normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
      LocaleItem(
        identifier: "en_US", displayName: "English (US)",
        normalizedKey: SpeechLocale.normalizationKey("en_US"), isReserved: true),
    ]
    let result = manager.correctSelection(currentSelection: "en-US", items: items)
    #expect(result == "en_US")
  }
}
