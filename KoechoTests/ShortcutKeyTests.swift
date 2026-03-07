import AppKit
import Testing
@testable import Koecho

@MainActor
struct ShortcutKeyTests {
    // MARK: - displayName

    @Test func displayNameSingleModifier() {
        let shortcut = ShortcutKey(modifiers: [.control], character: "r")
        #expect(shortcut.displayName == "⌃R")
    }

    @Test func displayNameMultipleModifiers() {
        let shortcut = ShortcutKey(modifiers: [.command, .shift], character: "c")
        #expect(shortcut.displayName == "⇧⌘C")
    }

    @Test func displayNameAllModifiers() {
        let shortcut = ShortcutKey(modifiers: [.command, .shift, .option, .control], character: "a")
        #expect(shortcut.displayName == "⌃⌥⇧⌘A")
    }

    @Test func displayNameDigitCharacter() {
        let shortcut = ShortcutKey(modifiers: [.control, .option], character: "1")
        #expect(shortcut.displayName == "⌃⌥1")
    }

    @Test func displayNameSymbolCharacter() {
        let shortcut = ShortcutKey(modifiers: [.command, .shift], character: "-")
        #expect(shortcut.displayName == "⇧⌘-")
    }

    // MARK: - Character normalization

    @Test func characterNormalizedToLowercase() {
        let shortcut = ShortcutKey(modifiers: [.command], character: "C")
        #expect(shortcut.character == "c")
        #expect(shortcut.displayName == "⌘C")
    }

    // MARK: - Modifier display order (macOS standard: ⌃ ⌥ ⇧ ⌘)

    @Test func modifierDisplayOrder() {
        let sorted = [Modifier.command, .shift, .option, .control].sorted()
        #expect(sorted == [.control, .option, .shift, .command])
    }

    // MARK: - Codable round trip

    @Test func codableRoundTrip() throws {
        let original = ShortcutKey(modifiers: [.command, .shift], character: "c")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutKey.self, from: data)
        #expect(decoded == original)
    }

    @Test func codableSetOfModifiers() throws {
        let original = ShortcutKey(modifiers: [.control, .option, .command], character: "1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutKey.self, from: data)
        #expect(decoded.modifiers == [.control, .option, .command])
    }

    // MARK: - Equality

    @Test func equalityDifferentModifiers() {
        let a = ShortcutKey(modifiers: [.command], character: "c")
        let b = ShortcutKey(modifiers: [.command, .shift], character: "c")
        #expect(a != b)
    }

    @Test func equalitySameShortcut() {
        let a = ShortcutKey(modifiers: [.command, .shift], character: "c")
        let b = ShortcutKey(modifiers: [.shift, .command], character: "c")
        #expect(a == b)
    }

    @Test func equalityDifferentCharacter() {
        let a = ShortcutKey(modifiers: [.command], character: "c")
        let b = ShortcutKey(modifiers: [.command], character: "v")
        #expect(a != b)
    }

    // MARK: - modifiers(from:)

    @Test func modifiersFromFlags() {
        let flags: NSEvent.ModifierFlags = [.control, .shift]
        let result = ShortcutKey.modifiers(from: flags)
        #expect(result == [.control, .shift])
    }

    @Test func modifiersFromFlagsIgnoresOtherBits() {
        // .capsLock and .numericPad should be ignored
        let flags: NSEvent.ModifierFlags = [.command, .capsLock, .numericPad]
        let result = ShortcutKey.modifiers(from: flags)
        #expect(result == [.command])
    }

    @Test func modifiersFromEmptyFlags() {
        let result = ShortcutKey.modifiers(from: [])
        #expect(result.isEmpty)
    }

    // MARK: - isPrintableASCII

    @Test func printableASCIIAcceptsLetters() {
        #expect(ShortcutKey.isPrintableASCII("a") == true)
        #expect(ShortcutKey.isPrintableASCII("z") == true)
        #expect(ShortcutKey.isPrintableASCII("A") == true)
    }

    @Test func printableASCIIAcceptsDigits() {
        #expect(ShortcutKey.isPrintableASCII("1") == true)
        #expect(ShortcutKey.isPrintableASCII("0") == true)
    }

    @Test func printableASCIIAcceptsSymbols() {
        #expect(ShortcutKey.isPrintableASCII("-") == true)
        #expect(ShortcutKey.isPrintableASCII("!") == true)
        #expect(ShortcutKey.isPrintableASCII("~") == true)
    }

    @Test func printableASCIIRejectsSpace() {
        #expect(ShortcutKey.isPrintableASCII(" ") == false)
    }

    @Test func printableASCIIRejectsControlCharacters() {
        #expect(ShortcutKey.isPrintableASCII("\u{00}") == false)
        #expect(ShortcutKey.isPrintableASCII("\u{1F}") == false)
        #expect(ShortcutKey.isPrintableASCII("\u{7F}") == false)
    }

    @Test func printableASCIIRejectsNonASCII() {
        #expect(ShortcutKey.isPrintableASCII("あ") == false)
        #expect(ShortcutKey.isPrintableASCII("\u{F700}") == false) // function key range
    }

    @Test func printableASCIIRejectsEmptyString() {
        #expect(ShortcutKey.isPrintableASCII("") == false)
    }

    @Test func printableASCIIRejectsMultiCharacter() {
        #expect(ShortcutKey.isPrintableASCII("ab") == false)
    }

    // MARK: - hasRequiredModifier

    @Test func hasRequiredModifierAcceptsControl() {
        #expect(ShortcutKey.hasRequiredModifier([.control]) == true)
    }

    @Test func hasRequiredModifierAcceptsCommand() {
        #expect(ShortcutKey.hasRequiredModifier([.command]) == true)
    }

    @Test func hasRequiredModifierAcceptsOption() {
        #expect(ShortcutKey.hasRequiredModifier([.option]) == true)
    }

    @Test func hasRequiredModifierAcceptsControlShift() {
        #expect(ShortcutKey.hasRequiredModifier([.control, .shift]) == true)
    }

    @Test func hasRequiredModifierRejectsShiftOnly() {
        #expect(ShortcutKey.hasRequiredModifier([.shift]) == false)
    }

    @Test func hasRequiredModifierRejectsEmpty() {
        #expect(ShortcutKey.hasRequiredModifier([]) == false)
    }

    // MARK: - Modifier symbols

    @Test func modifierSymbols() {
        #expect(Modifier.control.symbol == "⌃")
        #expect(Modifier.option.symbol == "⌥")
        #expect(Modifier.shift.symbol == "⇧")
        #expect(Modifier.command.symbol == "⌘")
    }

    // MARK: - Modifier flags

    @Test func modifierFlags() {
        #expect(Modifier.control.flag == .control)
        #expect(Modifier.option.flag == .option)
        #expect(Modifier.shift.flag == .shift)
        #expect(Modifier.command.flag == .command)
    }
}
