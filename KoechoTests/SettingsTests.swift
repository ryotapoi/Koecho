import Foundation
import Testing
@testable import Koecho

@MainActor
struct SettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func createsAllSubSettings() {
        let settings = Settings(defaults: makeDefaults())

        // Verify all sub-settings are created and accessible
        _ = settings.voiceInput
        _ = settings.hotkey
        _ = settings.script
        _ = settings.replacement
        _ = settings.history
        _ = settings.paste
        _ = settings.volumeDucking
    }

    @Test func roundTripViaSubSettings() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.paste.pasteDelay = 5.0
        settings.script.scriptTimeout = 60.0
        settings.history.isHistoryEnabled = false
        settings.volumeDucking.isVolumeDuckingEnabled = true

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.paste.pasteDelay == 5.0)
        #expect(reloaded.script.scriptTimeout == 60.0)
        #expect(reloaded.history.isHistoryEnabled == false)
        #expect(reloaded.volumeDucking.isVolumeDuckingEnabled == true)
    }

    @Test func subSettingsShareSameDefaults() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)

        // Modify via sub-settings
        settings.script.addScript(Script(name: "Test", scriptPath: "/bin/test"))
        settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "b"))

        // Reload via fresh Settings (same defaults) and verify
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.script.scripts.count == 1)
        #expect(reloaded.replacement.replacementRules.count == 1)
    }
}
