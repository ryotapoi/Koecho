import Foundation
import Testing

@testable import KoechoCore

@MainActor
struct ScriptSettingsTests {
  private func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
  }

  private func makeEmptySettings() -> ScriptSettings {
    let settings = ScriptSettings(defaults: makeDefaults())
    settings.scripts = []
    return settings
  }

  @Test func defaultValues() {
    let settings = ScriptSettings(defaults: makeDefaults())
    #expect(settings.scripts == Script.defaultBuiltins)
    #expect(settings.scriptTimeout == 30.0)
    #expect(settings.autoRunScriptId == nil)
    #expect(settings.autoRunShortcutKey == nil)
    #expect(settings.autoRunScript == nil)
  }

  @Test func registersBuiltinsOnceInFeatureOrder() {
    let defaults = makeDefaults()
    let first = ScriptSettings(defaults: defaults)
    let reloaded = ScriptSettings(defaults: defaults)

    #expect(first.scripts == Script.defaultBuiltins)
    #expect(reloaded.scripts == Script.defaultBuiltins)
    #expect(reloaded.scripts.map(\.builtin?.feature) == [.decreaseIndent, .increaseIndent, .blockQuote])
    #expect(reloaded.scripts.map(\.builtin?.indentationWidth) == [.two, .two, nil])
  }

  @Test func doesNotRestoreDeletedBuiltinAfterRegistration() {
    let defaults = makeDefaults()
    let settings = ScriptSettings(defaults: defaults)
    let deletedID = settings.scripts[0].id

    settings.deleteScript(id: deletedID)

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(!reloaded.scripts.contains { $0.id == deletedID })
    #expect(reloaded.scripts.count == 2)
  }

  @Test func migratesLegacyCustomScriptsAndRetainsTheirFields() throws {
    let defaults = makeDefaults()
    let id = UUID()
    let legacyJSON = """
      [{
        "id": "\(id.uuidString)",
        "name": "Legacy",
        "scriptPath": "/usr/local/bin/legacy --flag",
        "shortcutKey": { "modifiers": ["control"], "character": "l" },
        "requiresPrompt": true
      }]
      """
    defaults.set(Data(legacyJSON.utf8), forKey: "scripts")

    let settings = ScriptSettings(defaults: defaults)
    let migrated = try #require(settings.scripts.first)

    #expect(migrated.kind == .custom)
    #expect(migrated.id == id)
    #expect(migrated.name == "Legacy")
    #expect(migrated.scriptPath == "/usr/local/bin/legacy --flag")
    #expect(migrated.shortcutKey == ShortcutKey(modifiers: [.control], character: "l"))
    #expect(migrated.requiresPrompt)
    #expect(Array(settings.scripts.dropFirst()) == Script.defaultBuiltins)

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.scripts.first == migrated)
    #expect(Array(reloaded.scripts.dropFirst()) == Script.defaultBuiltins)
  }

  @Test func builtinRoundTripUsesFeatureContractAndKeepsPromptDisabled() {
    let defaults = makeDefaults()
    let settings = ScriptSettings(defaults: defaults)
    var builtin = Script.defaultBuiltins[0]
    builtin.name = "Edited"
    builtin.scriptPath = "/tmp/edited"
    builtin.requiresPrompt = true
    builtin.shortcutKey = ShortcutKey(modifiers: [.control], character: "d")
    settings.scripts = [builtin]

    let reloaded = ScriptSettings(defaults: defaults)
    let decoded = reloaded.scripts[0]
    #expect(decoded.kind == .builtin)
    #expect(decoded.builtin?.feature == .decreaseIndent)
    #expect(decoded.builtin?.indentationWidth == .two)
    #expect(decoded.name == "Decrease Indent")
    #expect(decoded.scriptPath.isEmpty)
    #expect(!decoded.requiresPrompt)
    #expect(decoded.shortcutKey == ShortcutKey(modifiers: [.control], character: "d"))
  }

  @Test func persistsScriptWithAllFields() {
    let defaults = makeDefaults()
    let script = Script(
      name: "Test Script",
      scriptPath: "/usr/local/bin/test.sh",
      shortcutKey: ShortcutKey(modifiers: [.control], character: "1"),
      requiresPrompt: true
    )

    let settings = ScriptSettings(defaults: defaults)
    settings.scripts = [script]

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.scripts.count == 1)
    let loaded = reloaded.scripts[0]
    #expect(loaded.id == script.id)
    #expect(loaded.name == "Test Script")
    #expect(loaded.scriptPath == "/usr/local/bin/test.sh")
    #expect(loaded.shortcutKey == ShortcutKey(modifiers: [.control], character: "1"))
    #expect(loaded.requiresPrompt == true)
  }

  @Test func corruptedDataFallsBackToDefaults() {
    let defaults = makeDefaults()
    defaults.set(Data("invalid json".utf8), forKey: "scripts")

    let settings = ScriptSettings(defaults: defaults)
    #expect(settings.scripts == Script.defaultBuiltins)
  }

  @Test func persistsMultipleScripts() {
    let defaults = makeDefaults()
    let scripts = [
      Script(name: "First", scriptPath: "/bin/first"),
      Script(name: "Second", scriptPath: "/bin/second"),
      Script(name: "Third", scriptPath: "/bin/third"),
    ]

    let settings = ScriptSettings(defaults: defaults)
    settings.scripts = scripts

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.scripts.count == 3)
    #expect(reloaded.scripts[0].name == "First")
    #expect(reloaded.scripts[1].name == "Second")
    #expect(reloaded.scripts[2].name == "Third")
  }

  // MARK: - CRUD Methods

  @Test func addScript() {
    let settings = makeEmptySettings()
    let script = Script(name: "New", scriptPath: "/bin/new")

    settings.addScript(script)

    #expect(settings.scripts.count == 1)
    #expect(settings.scripts[0].id == script.id)
  }

  @Test func updateScript() {
    let settings = makeEmptySettings()
    var script = Script(name: "Original", scriptPath: "/bin/original")
    settings.addScript(script)

    script.name = "Updated"
    script.scriptPath = "/bin/updated"
    settings.updateScript(script)

    #expect(settings.scripts.count == 1)
    #expect(settings.scripts[0].name == "Updated")
    #expect(settings.scripts[0].scriptPath == "/bin/updated")
  }

  @Test func updateNonexistentScript() {
    let settings = makeEmptySettings()
    settings.addScript(Script(name: "Existing", scriptPath: "/bin/existing"))

    let nonexistent = Script(name: "Ghost", scriptPath: "/bin/ghost")
    settings.updateScript(nonexistent)

    #expect(settings.scripts.count == 1)
    #expect(settings.scripts[0].name == "Existing")
  }

  @Test func deleteScript() {
    let settings = makeEmptySettings()
    let script = Script(name: "Doomed", scriptPath: "/bin/doomed")
    settings.addScript(script)

    settings.deleteScript(id: script.id)

    #expect(settings.scripts.isEmpty)
  }

  @Test func deleteNonexistentScript() {
    let settings = makeEmptySettings()
    settings.addScript(Script(name: "Safe", scriptPath: "/bin/safe"))

    settings.deleteScript(id: UUID())

    #expect(settings.scripts.count == 1)
    #expect(settings.scripts[0].name == "Safe")
  }

  @Test func clampsScriptTimeoutToOne() {
    let settings = makeEmptySettings()
    settings.scriptTimeout = 0
    #expect(settings.scriptTimeout == 1.0)

    settings.scriptTimeout = -5.0
    #expect(settings.scriptTimeout == 1.0)
  }

  @Test func moveScripts() {
    let settings = makeEmptySettings()
    let a = Script(name: "A", scriptPath: "/bin/a")
    let b = Script(name: "B", scriptPath: "/bin/b")
    let c = Script(name: "C", scriptPath: "/bin/c")
    settings.scripts = [a, b, c]

    settings.moveScripts(from: IndexSet(integer: 2), to: 0)

    #expect(settings.scripts[0].name == "C")
    #expect(settings.scripts[1].name == "A")
    #expect(settings.scripts[2].name == "B")
  }

  @Test func addScriptPersists() {
    let defaults = makeDefaults()
    let settings = ScriptSettings(defaults: defaults)
    settings.scripts = []
    let script = Script(name: "Persistent", scriptPath: "/bin/persist")

    settings.addScript(script)

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.scripts.count == 1)
    #expect(reloaded.scripts[0].name == "Persistent")
  }

  @Test func deleteScriptPersists() {
    let defaults = makeDefaults()
    let settings = ScriptSettings(defaults: defaults)
    settings.scripts = []
    let script = Script(name: "Temporary", scriptPath: "/bin/temp")
    settings.addScript(script)
    settings.deleteScript(id: script.id)

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.scripts.isEmpty)
  }

  // MARK: - Auto-Run Script

  @Test func autoRunScriptIdPersistence() {
    let defaults = makeDefaults()
    let scriptId = UUID()

    let settings = ScriptSettings(defaults: defaults)
    settings.autoRunScriptId = scriptId

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.autoRunScriptId == scriptId)
  }

  @Test func autoRunScriptIdNilPersistence() {
    let defaults = makeDefaults()

    let settings = ScriptSettings(defaults: defaults)
    settings.autoRunScriptId = UUID()
    settings.autoRunScriptId = nil

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.autoRunScriptId == nil)
  }

  // MARK: - Eligible Auto-Run Scripts

  @Test func eligibleAutoRunScriptsEmpty() {
    let settings = makeEmptySettings()
    #expect(settings.eligibleAutoRunScripts.isEmpty)
  }

  @Test func eligibleAutoRunScriptsExcludesPromptScripts() {
    let settings = makeEmptySettings()
    settings.scripts = [
      Script(name: "Prompt Only", scriptPath: "/bin/echo", requiresPrompt: true)
    ]
    #expect(settings.eligibleAutoRunScripts.isEmpty)
  }

  @Test func eligibleAutoRunScriptsIncludesNonPromptScripts() {
    let settings = makeEmptySettings()
    let a = Script(name: "A", scriptPath: "/bin/a")
    let b = Script(name: "B", scriptPath: "/bin/b")
    settings.scripts = [a, b]
    #expect(settings.eligibleAutoRunScripts.count == 2)
    #expect(settings.eligibleAutoRunScripts[0].id == a.id)
    #expect(settings.eligibleAutoRunScripts[1].id == b.id)
  }

  @Test func eligibleAutoRunScriptsFiltersMixed() {
    let settings = makeEmptySettings()
    let prompt = Script(name: "Prompt", scriptPath: "/bin/echo", requiresPrompt: true)
    let normal = Script(name: "Normal", scriptPath: "/bin/echo")
    settings.scripts = [prompt, normal]
    #expect(settings.eligibleAutoRunScripts.count == 1)
    #expect(settings.eligibleAutoRunScripts[0].id == normal.id)
  }

  @Test func autoRunScriptFiltersRequiresPrompt() {
    let settings = makeEmptySettings()
    let promptScript = Script(name: "Prompt", scriptPath: "/bin/echo", requiresPrompt: true)
    let normalScript = Script(name: "Normal", scriptPath: "/bin/echo")
    settings.scripts = [promptScript, normalScript]

    settings.autoRunScriptId = promptScript.id
    #expect(settings.autoRunScript == nil)

    settings.autoRunScriptId = normalScript.id
    #expect(settings.autoRunScript?.id == normalScript.id)
  }

  @Test func builtinScriptsAreNeverEligibleForAutoRun() {
    let settings = ScriptSettings(defaults: makeDefaults())
    let builtin = settings.scripts[0]

    #expect(settings.eligibleAutoRunScripts.isEmpty)
    settings.autoRunScriptId = builtin.id
    #expect(settings.autoRunScript == nil)
  }

  @Test func deleteScriptClearsAutoRunScriptId() {
    let settings = makeEmptySettings()
    let script = Script(name: "Test", scriptPath: "/bin/echo")
    settings.scripts = [script]
    settings.autoRunScriptId = script.id

    settings.deleteScript(id: script.id)

    #expect(settings.autoRunScriptId == nil)
  }

  @Test func autoRunShortcutKeyPersistence() {
    let defaults = makeDefaults()
    let shortcut = ShortcutKey(modifiers: [.control, .shift], character: "a")

    let settings = ScriptSettings(defaults: defaults)
    settings.autoRunShortcutKey = shortcut

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.autoRunShortcutKey == shortcut)
  }

  @Test func autoRunShortcutKeyNilPersistence() {
    let defaults = makeDefaults()

    let settings = ScriptSettings(defaults: defaults)
    settings.autoRunShortcutKey = ShortcutKey(modifiers: [.control], character: "a")
    settings.autoRunShortcutKey = nil

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(reloaded.autoRunShortcutKey == nil)
  }

  @Test func emptyAutoRunShortcutDataRemainsDisabled() {
    let defaults = makeDefaults()
    defaults.set(Data(), forKey: "autoRunShortcut")

    let settings = ScriptSettings(defaults: defaults)

    #expect(settings.autoRunShortcutKey == nil)
  }

  @Test func corruptAutoRunShortcutDataFallsBackToNil() {
    let defaults = makeDefaults()
    defaults.set(Data("invalid json".utf8), forKey: "autoRunShortcut")

    let settings = ScriptSettings(defaults: defaults)

    #expect(settings.autoRunShortcutKey == nil)
  }

  @Test func clampsPersistedScriptTimeout() {
    let defaults = makeDefaults()
    defaults.set(-5.0, forKey: "scriptTimeout")

    let settings = ScriptSettings(defaults: defaults)
    #expect(settings.scriptTimeout == 1.0)
  }
}
