import Foundation
import Testing
@testable import Koecho

@MainActor
struct PasteSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultPasteDelay() {
        let settings = PasteSettings(defaults: makeDefaults())
        #expect(settings.pasteDelay == 2.0)
    }

    @Test func persistsPasteDelay() {
        let defaults = makeDefaults()

        let settings = PasteSettings(defaults: defaults)
        settings.pasteDelay = 5.0

        let reloaded = PasteSettings(defaults: defaults)
        #expect(reloaded.pasteDelay == 5.0)
    }

    @Test func clampsPasteDelayToZero() {
        let settings = PasteSettings(defaults: makeDefaults())
        settings.pasteDelay = -1.0
        #expect(settings.pasteDelay == 0.0)
    }

    @Test func clampsNegativeValuesOnInit() {
        let defaults = makeDefaults()
        defaults.set(-3.0, forKey: "pasteDelay")

        let settings = PasteSettings(defaults: defaults)
        #expect(settings.pasteDelay == 0.0)
    }

    @Test func clampsPersistedValues() {
        let defaults = makeDefaults()
        let settings = PasteSettings(defaults: defaults)
        settings.pasteDelay = -1.0

        let reloaded = PasteSettings(defaults: defaults)
        #expect(reloaded.pasteDelay == 0.0)
    }
}
