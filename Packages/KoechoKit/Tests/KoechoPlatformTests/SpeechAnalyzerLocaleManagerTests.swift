import Foundation
import KoechoCore
import Testing
@testable import KoechoPlatform

@MainActor
struct SpeechAnalyzerLocaleManagerTests {
    @Test func initialState() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        #expect(manager.allLocales.isEmpty)
        #expect(manager.isLoading == true)
        #expect(manager.isDownloading == false)
        #expect(manager.downloadError == nil)
        #expect(manager.reservedLocales.isEmpty)
    }

    @Test func clearDownloadError() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        manager.clearDownloadError()
        #expect(manager.downloadError == nil)
    }

    @Test func findNormalizedMatchExactMatch() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "en-US", displayName: "English (US)", sortKey: "English (US)", isReserved: true),
            LocaleItem(identifier: "ja-JP", displayName: "Japanese", sortKey: "Japanese", isReserved: true),
        ]
        let match = manager.findNormalizedMatch(for: "en-US", in: items)
        #expect(match?.identifier == "en-US")
    }

    @Test func findNormalizedMatchNormalized() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "en_US", displayName: "English (US)", sortKey: "English (US)", isReserved: true),
        ]
        let match = manager.findNormalizedMatch(for: "en-US", in: items)
        #expect(match?.identifier == "en_US")
    }

    @Test func findNormalizedMatchNoMatch() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "en-US", displayName: "English (US)", sortKey: "English (US)", isReserved: true),
        ]
        let match = manager.findNormalizedMatch(for: "fr-FR", in: items)
        #expect(match == nil)
    }

    @Test func reservedLocalesFiltersCorrectly() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        #expect(manager.reservedLocales.isEmpty)
    }

    // MARK: - correctSelection

    @Test func correctSelectionWhenSelectionInReserved() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "en-US", displayName: "English (US)", sortKey: "English (US)", isReserved: true),
        ]
        let result = manager.correctSelection(currentSelection: "en-US", items: items)
        #expect(result == nil)
    }

    @Test func correctSelectionWhenSelectionInAll() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "en-US", displayName: "English (US)", sortKey: "English (US)", isReserved: false),
        ]
        let result = manager.correctSelection(currentSelection: "en-US", items: items)
        #expect(result == nil)
    }

    @Test func correctSelectionNormalizedMatch() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "en_US", displayName: "English (US)", sortKey: "English (US)", isReserved: true),
        ]
        let result = manager.correctSelection(currentSelection: "en-US", items: items)
        #expect(result == "en_US")
    }

    @Test func correctSelectionJaJPFallback() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "ja-JP", displayName: "Japanese", sortKey: "Japanese", isReserved: true),
            LocaleItem(identifier: "fr-FR", displayName: "French", sortKey: "French", isReserved: true),
        ]
        let result = manager.correctSelection(currentSelection: "de-DE", items: items)
        #expect(result == "ja-JP")
    }

    @Test func correctSelectionFirstItemFallback() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "fr-FR", displayName: "French", sortKey: "French", isReserved: true),
            LocaleItem(identifier: "de-DE", displayName: "German", sortKey: "German", isReserved: true),
        ]
        let result = manager.correctSelection(currentSelection: "zh-CN", items: items)
        #expect(result == "fr-FR")
    }

    @Test func correctSelectionEmptyItems() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let result = manager.correctSelection(currentSelection: "en-US", items: [])
        #expect(result == nil)
    }

    @Test func correctSelectionNormalizedPriorityOverJaJP() {
        guard #available(macOS 26, *) else { return }
        let manager = SpeechAnalyzerLocaleManager()
        let items = [
            LocaleItem(identifier: "ja-JP", displayName: "Japanese", sortKey: "Japanese", isReserved: true),
            LocaleItem(identifier: "en_US", displayName: "English (US)", sortKey: "English (US)", isReserved: true),
        ]
        let result = manager.correctSelection(currentSelection: "en-US", items: items)
        #expect(result == "en_US")
    }
}
