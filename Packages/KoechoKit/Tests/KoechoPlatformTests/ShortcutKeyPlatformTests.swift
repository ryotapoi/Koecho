import AppKit
import KoechoCore
import Testing
@testable import KoechoPlatform

@MainActor
struct ShortcutKeyPlatformTests {
    // MARK: - modifiers(from:)

    @Test func modifiersFromFlags() {
        let flags: NSEvent.ModifierFlags = [.control, .shift]
        let result = ShortcutKey.modifiers(from: flags)
        #expect(result == [.control, .shift])
    }

    @Test func modifiersFromFlagsIgnoresOtherBits() {
        let flags: NSEvent.ModifierFlags = [.command, .capsLock, .numericPad]
        let result = ShortcutKey.modifiers(from: flags)
        #expect(result == [.command])
    }

    @Test func modifiersFromEmptyFlags() {
        let result = ShortcutKey.modifiers(from: [])
        #expect(result.isEmpty)
    }

    // MARK: - Modifier flags

    @Test func modifierFlags() {
        #expect(Modifier.control.flag == .control)
        #expect(Modifier.option.flag == .option)
        #expect(Modifier.shift.flag == .shift)
        #expect(Modifier.command.flag == .command)
    }
}
