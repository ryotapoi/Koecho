import KoechoCore
import Testing

@testable import Koecho

@Suite struct ShortcutKeyRecorderEventDecisionTests {
  @Test func escapeCancelsRecording() {
    let result = ShortcutKeyRecorderEventDecision.decide(
      keyCode: 53,
      characters: "a",
      modifiers: [.command]
    )

    #expect(result == .cancel)
  }

  @Test func invalidCharactersAreIgnored() {
    let cases: [String?] = [nil, "", " ", "あ", "ab"]

    for characters in cases {
      let result = ShortcutKeyRecorderEventDecision.decide(
        keyCode: 0,
        characters: characters,
        modifiers: [.command]
      )

      #expect(result == .ignore)
    }
  }

  @Test func missingRequiredModifierIsIgnored() {
    #expect(
      ShortcutKeyRecorderEventDecision.decide(
        keyCode: 0,
        characters: "a",
        modifiers: []
      ) == .ignore
    )
    #expect(
      ShortcutKeyRecorderEventDecision.decide(
        keyCode: 0,
        characters: "a",
        modifiers: [.shift]
      ) == .ignore
    )
  }

  @Test func requiredModifiersRecordLowercasedPrintableASCII() {
    let cases: [(Set<Modifier>, ShortcutKey)] = [
      ([.control], ShortcutKey(modifiers: [.control], character: "r")),
      ([.command, .shift], ShortcutKey(modifiers: [.command, .shift], character: "c")),
      ([.option], ShortcutKey(modifiers: [.option], character: "1")),
    ]

    for (modifiers, expectedShortcut) in cases {
      let result = ShortcutKeyRecorderEventDecision.decide(
        keyCode: 0,
        characters: expectedShortcut.character.uppercased(),
        modifiers: modifiers
      )

      #expect(result == .record(expectedShortcut))
    }
  }
}
