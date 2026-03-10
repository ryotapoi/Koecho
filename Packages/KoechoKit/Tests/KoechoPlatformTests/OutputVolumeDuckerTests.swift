import Foundation
import KoechoCore
import Testing
@testable import KoechoPlatform

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
        ducker.restore()
        #expect(ducker.isDucked == false)
    }

    @Test func enabledDuckDoesNotCrash() {
        let settings = makeSettings(enabled: true, level: 1.0)
        let ducker = OutputVolumeDucker(settings: settings)
        ducker.duck()
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
