import Foundation
import Testing
@testable import Koecho

@MainActor
struct SettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultValues() {
        let settings = Settings(defaults: makeDefaults())

        #expect(settings.pasteDelay == 2.0)
        #expect(settings.scriptTimeout == 30.0)
        #expect(settings.scripts.isEmpty)
    }

    @Test func persistsChanges() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.pasteDelay = 5.0
        settings.scriptTimeout = 60.0

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.pasteDelay == 5.0)
        #expect(reloaded.scriptTimeout == 60.0)
    }

    @Test func persistsScriptWithAllFields() {
        let defaults = makeDefaults()
        let script = Script(
            name: "Test Script",
            scriptPath: "/usr/local/bin/test.sh",
            shortcutKey: "1",
            requiresPrompt: true
        )

        let settings = Settings(defaults: defaults)
        settings.scripts = [script]

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.scripts.count == 1)
        let loaded = reloaded.scripts[0]
        #expect(loaded.id == script.id)
        #expect(loaded.name == "Test Script")
        #expect(loaded.scriptPath == "/usr/local/bin/test.sh")
        #expect(loaded.shortcutKey == "1")
        #expect(loaded.requiresPrompt == true)
    }

    @Test func corruptedDataFallsBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("invalid json".utf8), forKey: "scripts")
        defaults.set("not a number", forKey: "pasteDelay")

        let settings = Settings(defaults: defaults)
        #expect(settings.pasteDelay == 2.0)
        #expect(settings.scripts.isEmpty)
    }

    @Test func persistsMultipleScripts() {
        let defaults = makeDefaults()
        let scripts = [
            Script(name: "First", scriptPath: "/bin/first"),
            Script(name: "Second", scriptPath: "/bin/second"),
            Script(name: "Third", scriptPath: "/bin/third"),
        ]

        let settings = Settings(defaults: defaults)
        settings.scripts = scripts

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.scripts.count == 3)
        #expect(reloaded.scripts[0].name == "First")
        #expect(reloaded.scripts[1].name == "Second")
        #expect(reloaded.scripts[2].name == "Third")
    }

    // MARK: - CRUD Methods

    @Test func addScript() {
        let settings = Settings(defaults: makeDefaults())
        let script = Script(name: "New", scriptPath: "/bin/new")

        settings.addScript(script)

        #expect(settings.scripts.count == 1)
        #expect(settings.scripts[0].id == script.id)
    }

    @Test func updateScript() {
        let settings = Settings(defaults: makeDefaults())
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
        let settings = Settings(defaults: makeDefaults())
        settings.addScript(Script(name: "Existing", scriptPath: "/bin/existing"))

        let nonexistent = Script(name: "Ghost", scriptPath: "/bin/ghost")
        settings.updateScript(nonexistent)

        #expect(settings.scripts.count == 1)
        #expect(settings.scripts[0].name == "Existing")
    }

    @Test func deleteScript() {
        let settings = Settings(defaults: makeDefaults())
        let script = Script(name: "Doomed", scriptPath: "/bin/doomed")
        settings.addScript(script)

        settings.deleteScript(id: script.id)

        #expect(settings.scripts.isEmpty)
    }

    @Test func deleteNonexistentScript() {
        let settings = Settings(defaults: makeDefaults())
        settings.addScript(Script(name: "Safe", scriptPath: "/bin/safe"))

        settings.deleteScript(id: UUID())

        #expect(settings.scripts.count == 1)
        #expect(settings.scripts[0].name == "Safe")
    }

    // MARK: - Value Clamping

    @Test func clampsPasteDelayToZero() {
        let settings = Settings(defaults: makeDefaults())
        settings.pasteDelay = -1.0
        #expect(settings.pasteDelay == 0.0)
    }

    @Test func clampsScriptTimeoutToOne() {
        let settings = Settings(defaults: makeDefaults())
        settings.scriptTimeout = 0
        #expect(settings.scriptTimeout == 1.0)

        settings.scriptTimeout = -5.0
        #expect(settings.scriptTimeout == 1.0)
    }

    @Test func clampsPersistedValues() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        settings.pasteDelay = -1.0
        settings.scriptTimeout = 0

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.pasteDelay == 0.0)
        #expect(reloaded.scriptTimeout == 1.0)
    }

    @Test func clampsNegativeValuesOnInit() {
        let defaults = makeDefaults()
        defaults.set(-3.0, forKey: "pasteDelay")
        defaults.set(-5.0, forKey: "scriptTimeout")

        let settings = Settings(defaults: defaults)
        #expect(settings.pasteDelay == 0.0)
        #expect(settings.scriptTimeout == 1.0)
    }

    // MARK: - Script Ordering

    @Test func moveScripts() {
        let settings = Settings(defaults: makeDefaults())
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
        let settings = Settings(defaults: defaults)
        let script = Script(name: "Persistent", scriptPath: "/bin/persist")

        settings.addScript(script)

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.scripts.count == 1)
        #expect(reloaded.scripts[0].name == "Persistent")
    }

    @Test func deleteScriptPersists() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        let script = Script(name: "Temporary", scriptPath: "/bin/temp")
        settings.addScript(script)
        settings.deleteScript(id: script.id)

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.scripts.isEmpty)
    }
}
