import Foundation
import Testing
@testable import Koecho

@MainActor
struct VolumeDuckingSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultVolumeDuckingSettings() {
        let settings = VolumeDuckingSettings(defaults: makeDefaults())
        #expect(settings.isVolumeDuckingEnabled == false)
        #expect(settings.volumeDuckingLevel == 0.05)
    }

    @Test func persistsVolumeDuckingSettings() {
        let defaults = makeDefaults()

        let settings = VolumeDuckingSettings(defaults: defaults)
        settings.isVolumeDuckingEnabled = true
        settings.volumeDuckingLevel = 0.5

        let reloaded = VolumeDuckingSettings(defaults: defaults)
        #expect(reloaded.isVolumeDuckingEnabled == true)
        #expect(reloaded.volumeDuckingLevel == 0.5)
    }

    @Test func clampsVolumeDuckingLevel() {
        let settings = VolumeDuckingSettings(defaults: makeDefaults())

        settings.volumeDuckingLevel = -0.5
        #expect(settings.volumeDuckingLevel == 0.0)

        settings.volumeDuckingLevel = 1.5
        #expect(settings.volumeDuckingLevel == 1.0)

        settings.volumeDuckingLevel = 0.7
        #expect(settings.volumeDuckingLevel == 0.7)
    }

    @Test func clampsVolumeDuckingLevelOnInit() {
        let defaults = makeDefaults()
        defaults.set(Float(-0.5), forKey: "volumeDuckingLevel")

        let settings = VolumeDuckingSettings(defaults: defaults)
        #expect(settings.volumeDuckingLevel == 0.0)
    }
}
