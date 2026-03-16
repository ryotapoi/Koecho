import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct ScriptSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultValues() {
        let settings = ScriptSettings(defaults: makeDefaults())
        #expect(settings.scripts.isEmpty)
        #expect(settings.scriptTimeout == 30.0)
        #expect(settings.autoRunScriptId == nil)
        #expect(settings.autoRunShortcutKey == nil)
        #expect(settings.autoRunScript == nil)
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
        #expect(settings.scripts.isEmpty)
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
        let settings = ScriptSettings(defaults: makeDefaults())
        let script = Script(name: "New", scriptPath: "/bin/new")

        settings.addScript(script)

        #expect(settings.scripts.count == 1)
        #expect(settings.scripts[0].id == script.id)
    }

    @Test func updateScript() {
        let settings = ScriptSettings(defaults: makeDefaults())
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
        let settings = ScriptSettings(defaults: makeDefaults())
        settings.addScript(Script(name: "Existing", scriptPath: "/bin/existing"))

        let nonexistent = Script(name: "Ghost", scriptPath: "/bin/ghost")
        settings.updateScript(nonexistent)

        #expect(settings.scripts.count == 1)
        #expect(settings.scripts[0].name == "Existing")
    }

    @Test func deleteScript() {
        let settings = ScriptSettings(defaults: makeDefaults())
        let script = Script(name: "Doomed", scriptPath: "/bin/doomed")
        settings.addScript(script)

        settings.deleteScript(id: script.id)

        #expect(settings.scripts.isEmpty)
    }

    @Test func deleteNonexistentScript() {
        let settings = ScriptSettings(defaults: makeDefaults())
        settings.addScript(Script(name: "Safe", scriptPath: "/bin/safe"))

        settings.deleteScript(id: UUID())

        #expect(settings.scripts.count == 1)
        #expect(settings.scripts[0].name == "Safe")
    }

    @Test func clampsScriptTimeoutToOne() {
        let settings = ScriptSettings(defaults: makeDefaults())
        settings.scriptTimeout = 0
        #expect(settings.scriptTimeout == 1.0)

        settings.scriptTimeout = -5.0
        #expect(settings.scriptTimeout == 1.0)
    }

    @Test func moveScripts() {
        let settings = ScriptSettings(defaults: makeDefaults())
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
        let script = Script(name: "Persistent", scriptPath: "/bin/persist")

        settings.addScript(script)

        let reloaded = ScriptSettings(defaults: defaults)
        #expect(reloaded.scripts.count == 1)
        #expect(reloaded.scripts[0].name == "Persistent")
    }

    @Test func deleteScriptPersists() {
        let defaults = makeDefaults()
        let settings = ScriptSettings(defaults: defaults)
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
        let settings = ScriptSettings(defaults: makeDefaults())
        #expect(settings.eligibleAutoRunScripts.isEmpty)
    }

    @Test func eligibleAutoRunScriptsExcludesPromptScripts() {
        let settings = ScriptSettings(defaults: makeDefaults())
        settings.scripts = [
            Script(name: "Prompt Only", scriptPath: "/bin/echo", requiresPrompt: true),
        ]
        #expect(settings.eligibleAutoRunScripts.isEmpty)
    }

    @Test func eligibleAutoRunScriptsIncludesNonPromptScripts() {
        let settings = ScriptSettings(defaults: makeDefaults())
        let a = Script(name: "A", scriptPath: "/bin/a")
        let b = Script(name: "B", scriptPath: "/bin/b")
        settings.scripts = [a, b]
        #expect(settings.eligibleAutoRunScripts.count == 2)
        #expect(settings.eligibleAutoRunScripts[0].id == a.id)
        #expect(settings.eligibleAutoRunScripts[1].id == b.id)
    }

    @Test func eligibleAutoRunScriptsFiltersMixed() {
        let settings = ScriptSettings(defaults: makeDefaults())
        let prompt = Script(name: "Prompt", scriptPath: "/bin/echo", requiresPrompt: true)
        let normal = Script(name: "Normal", scriptPath: "/bin/echo")
        settings.scripts = [prompt, normal]
        #expect(settings.eligibleAutoRunScripts.count == 1)
        #expect(settings.eligibleAutoRunScripts[0].id == normal.id)
    }

    @Test func autoRunScriptFiltersRequiresPrompt() {
        let settings = ScriptSettings(defaults: makeDefaults())
        let promptScript = Script(name: "Prompt", scriptPath: "/bin/echo", requiresPrompt: true)
        let normalScript = Script(name: "Normal", scriptPath: "/bin/echo")
        settings.scripts = [promptScript, normalScript]

        settings.autoRunScriptId = promptScript.id
        #expect(settings.autoRunScript == nil)

        settings.autoRunScriptId = normalScript.id
        #expect(settings.autoRunScript?.id == normalScript.id)
    }

    @Test func deleteScriptClearsAutoRunScriptId() {
        let settings = ScriptSettings(defaults: makeDefaults())
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

    @Test func clampsPersistedScriptTimeout() {
        let defaults = makeDefaults()
        defaults.set(-5.0, forKey: "scriptTimeout")

        let settings = ScriptSettings(defaults: defaults)
        #expect(settings.scriptTimeout == 1.0)
    }
}
