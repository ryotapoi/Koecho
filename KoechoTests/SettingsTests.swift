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
}
