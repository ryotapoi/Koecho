import Foundation
import Testing

import KoechoCore

struct ScriptTests {
  @Test func customSettersPreserveOtherValues() {
    let id = UUID()
    let shortcutKey = ShortcutKey(modifiers: [.control], character: "s")

    var script = Script(
      id: id,
      name: "Original",
      scriptPath: "/bin/original",
      shortcutKey: shortcutKey,
      requiresPrompt: true
    )
    script.name = "Renamed"
    #expect(script.name == "Renamed")
    #expect(script.scriptPath == "/bin/original")
    #expect(script.requiresPrompt)

    script.scriptPath = "/bin/updated"
    #expect(script.name == "Renamed")
    #expect(script.scriptPath == "/bin/updated")
    #expect(script.requiresPrompt)

    script.requiresPrompt = false
    #expect(script.name == "Renamed")
    #expect(script.scriptPath == "/bin/updated")
    #expect(!script.requiresPrompt)
    #expect(script.id == id)
    #expect(script.shortcutKey == shortcutKey)
  }

  @Test func encodeCustomUsesFlatSchema() throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let script = Script(
      id: id,
      name: "Custom",
      scriptPath: "/bin/custom",
      shortcutKey: ShortcutKey(modifiers: [.control], character: "c"),
      requiresPrompt: true
    )

    let object = try encodedObject(for: script)
    #expect(Set(object.keys) == ["id", "kind", "name", "scriptPath", "shortcutKey", "requiresPrompt"])
    #expect(object["id"] as? String == id.uuidString)
    #expect(object["kind"] as? String == "custom")
    #expect(object["name"] as? String == "Custom")
    #expect(object["scriptPath"] as? String == "/bin/custom")
    #expect(object["requiresPrompt"] as? Bool == true)
  }

  @Test func encodeBuiltinUsesFlatSchema() throws {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let script = Script(
      id: id,
      builtin: BuiltinScript(feature: .increaseIndent, indentationWidth: .four)!,
      shortcutKey: ShortcutKey(modifiers: [.option], character: "i")
    )

    let object = try encodedObject(for: script)
    #expect(Set(object.keys) == ["id", "kind", "shortcutKey", "builtinFeature", "indentationWidth"])
    #expect(object["id"] as? String == id.uuidString)
    #expect(object["kind"] as? String == "builtin")
    #expect(object["builtinFeature"] as? String == "increaseIndent")
    #expect(object["indentationWidth"] as? Int == 4)
  }

  @Test(arguments: [
    """
    { "id": "00000000-0000-0000-0000-000000000003", "kind": "builtin", "builtinFeature": "blockQuote", "indentationWidth": 2 }
    """,
    """
    { "id": "00000000-0000-0000-0000-000000000004", "kind": "builtin", "builtinFeature": "increaseIndent" }
    """,
  ])
  func decodeRejectsInvalidBuiltinFeatureWidthCombinations(json: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Script.self, from: Data(json.utf8))
    }
  }

  private func encodedObject(for script: Script) throws -> [String: Any] {
    let data = try JSONEncoder().encode(script)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
