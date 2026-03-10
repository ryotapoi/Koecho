import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct HotkeySettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultHotkeyConfig() {
        let settings = HotkeySettings(defaults: makeDefaults())
        #expect(settings.hotkeyConfig == .default)
        #expect(settings.hotkeyConfig.modifierKey == .fn)
        #expect(settings.hotkeyConfig.side == .left)
        #expect(settings.hotkeyConfig.tapMode == .singleToggle)
    }

    @Test func persistsHotkeyConfig() {
        let defaults = makeDefaults()

        let settings = HotkeySettings(defaults: defaults)
        settings.hotkeyConfig = HotkeyConfig(modifierKey: .command, side: .right, tapMode: .doubleTapToShow)

        let reloaded = HotkeySettings(defaults: defaults)
        #expect(reloaded.hotkeyConfig.modifierKey == .command)
        #expect(reloaded.hotkeyConfig.side == .right)
        #expect(reloaded.hotkeyConfig.tapMode == .doubleTapToShow)
    }

    @Test func fnSideCorrectedToLeft() {
        let settings = HotkeySettings(defaults: makeDefaults())
        settings.hotkeyConfig = HotkeyConfig(modifierKey: .fn, side: .right, tapMode: .singleToggle)
        #expect(settings.hotkeyConfig.side == .left)
    }

    @Test func corruptedHotkeyConfigFallsBack() {
        let defaults = makeDefaults()
        defaults.set(Data("invalid json".utf8), forKey: "hotkeyConfig")

        let settings = HotkeySettings(defaults: defaults)
        #expect(settings.hotkeyConfig == .default)
    }
}
