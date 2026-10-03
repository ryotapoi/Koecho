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

  @Test func printableASCIIValidation() {
    for character in ["a", "z", "A", "1", "0", "-", "!", "~"] {
      #expect(ShortcutKey.isPrintableASCII(character))
    }
    for character in [" ", "\u{00}", "\u{1F}", "\u{7F}", "あ", "\u{F700}", "", "ab"] {
      #expect(!ShortcutKey.isPrintableASCII(character))
    }
  }

  // MARK: - hasRequiredModifier

  @Test func requiredModifierValidation() {
    let accepted: [Set<Modifier>] = [
      [.control], [.command], [.option], [.control, .shift],
    ]
    for modifiers in accepted {
      #expect(ShortcutKey.hasRequiredModifier(modifiers))
    }
    let rejected: [Set<Modifier>] = [[.shift], []]
    for modifiers in rejected {
      #expect(!ShortcutKey.hasRequiredModifier(modifiers))
    }
  }
}
