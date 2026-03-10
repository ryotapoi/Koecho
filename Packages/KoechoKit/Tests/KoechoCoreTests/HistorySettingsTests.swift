import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct HistorySettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultHistorySettings() {
        let settings = HistorySettings(defaults: makeDefaults())

        #expect(settings.isHistoryEnabled == true)
        #expect(settings.historyMaxCount == 500)
        #expect(settings.historyRetentionDays == 30)
    }

    @Test func persistsHistorySettings() {
        let defaults = makeDefaults()

        let settings = HistorySettings(defaults: defaults)
        settings.isHistoryEnabled = false
        settings.historyMaxCount = 100
        settings.historyRetentionDays = 7

        let reloaded = HistorySettings(defaults: defaults)
        #expect(reloaded.isHistoryEnabled == false)
        #expect(reloaded.historyMaxCount == 100)
        #expect(reloaded.historyRetentionDays == 7)
    }

    @Test func clampsHistoryMaxCount() {
        let settings = HistorySettings(defaults: makeDefaults())
        settings.historyMaxCount = 0
        #expect(settings.historyMaxCount == 1)

        settings.historyMaxCount = -5
        #expect(settings.historyMaxCount == 1)
    }

    @Test func clampsHistoryRetentionDays() {
        let settings = HistorySettings(defaults: makeDefaults())
        settings.historyRetentionDays = 0
        #expect(settings.historyRetentionDays == 1)

        settings.historyRetentionDays = -5
        #expect(settings.historyRetentionDays == 1)
    }
}
