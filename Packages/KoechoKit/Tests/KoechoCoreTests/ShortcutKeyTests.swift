import Foundation
import Testing

@testable import KoechoCore

@MainActor
struct ShortcutKeyTests {
  // MARK: - displayName

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

  // MARK: - Optional persistence data

  @Test func optionalPersistenceDataRoundTrip() throws {
    let original = ShortcutKey(modifiers: [.command, .shift], character: "c")

    let data = try ShortcutKey.encodeOptional(original)

    #expect(try ShortcutKey.decodeOptional(from: data) == original)
  }

  @Test func emptyOptionalPersistenceDataDecodesAsNil() throws {
    #expect(try ShortcutKey.decodeOptional(from: Data()) == nil)
    #expect(try ShortcutKey.decodeOptional(from: nil) == nil)
    #expect(try ShortcutKey.encodeOptional(nil).isEmpty)
  }

  @Test func corruptOptionalPersistenceDataThrows() {
    let data = Data("invalid json".utf8)

    #expect(throws: (any Error).self) {
      try ShortcutKey.decodeOptional(from: data)
    }
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
    #expect(ShortcutKey.isPrintableASCII("\u{F700}") == false)  // function key range
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

}
