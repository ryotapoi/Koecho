import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct HotkeyConfigTests {
    // MARK: - Codable Round-trip

    @Test func codableRoundTrip() throws {
        let original = HotkeyConfig(modifierKey: .option, side: .right, tapMode: .doubleTapToShow)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyConfig.self, from: data)
        #expect(decoded == original)
    }

    @Test func codableRoundTripDefault() throws {
        let original = HotkeyConfig.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyConfig.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Default Values

    @Test func defaultValues() {
        let config = HotkeyConfig.default
        #expect(config.modifierKey == .fn)
        #expect(config.side == .left)
        #expect(config.tapMode == .singleToggle)
    }
}
