import Foundation
import Testing
@testable import Koecho

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
        // en-US and en_US should normalize to the same key
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
        // reservedLocales should be empty when allLocales is empty
        #expect(manager.reservedLocales.isEmpty)
    }
}
