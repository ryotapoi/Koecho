import Foundation
import Testing
@testable import Koecho

@MainActor
struct OutputVolumeDuckerTests {
    private func makeSettings(enabled: Bool = false, level: Float = 0.05) -> VolumeDuckingSettings {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = VolumeDuckingSettings(defaults: defaults)
        settings.isVolumeDuckingEnabled = enabled
        settings.volumeDuckingLevel = level
        return settings
    }

    @Test func disabledDuckDoesNothing() {
        let settings = makeSettings(enabled: false)
        let ducker = OutputVolumeDucker(settings: settings)

        ducker.duck()

        #expect(ducker.isDucked == false)
    }

    @Test func restoreWhenNotDuckedDoesNothing() {
        let settings = makeSettings(enabled: true)
        let ducker = OutputVolumeDucker(settings: settings)

        // Should not crash or change state
        ducker.restore()

        #expect(ducker.isDucked == false)
    }

    @Test func enabledDuckDoesNotCrash() {
        // Use level 1.0 so setOutputVolume is never called
        // (current volume <= 1.0 always, so target == current)
        let settings = makeSettings(enabled: true, level: 1.0)
        let ducker = OutputVolumeDucker(settings: settings)

        ducker.duck()

        // On CI without audio device, isDucked may be false (no device found)
        // On real Mac, isDucked should be true
        // Either way, this test verifies no crash
        ducker.restore()

        #expect(ducker.isDucked == false)
    }

    @Test func duckRestoreCycleDoesNotCrash() {
        let settings = makeSettings(enabled: true, level: 1.0)
        let ducker = OutputVolumeDucker(settings: settings)

        ducker.duck()
        ducker.restore()
        ducker.duck()
        ducker.restore()

        #expect(ducker.isDucked == false)
    }
}
