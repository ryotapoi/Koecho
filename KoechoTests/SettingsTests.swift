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

    // MARK: - Replacement Rules

    @Test func defaultReplacementRulesEmpty() {
        let settings = Settings(defaults: makeDefaults())
        #expect(settings.replacementRules.isEmpty)
    }

    @Test func addReplacementRule() {
        let settings = Settings(defaults: makeDefaults())
        let rule = ReplacementRule(pattern: "えーと", replacement: "")

        settings.addReplacementRule(rule)

        #expect(settings.replacementRules.count == 1)
        #expect(settings.replacementRules[0].id == rule.id)
    }

    @Test func updateReplacementRule() {
        let settings = Settings(defaults: makeDefaults())
        var rule = ReplacementRule(pattern: "a", replacement: "b")
        settings.addReplacementRule(rule)

        rule.pattern = "c"
        settings.updateReplacementRule(rule)

        #expect(settings.replacementRules.count == 1)
        #expect(settings.replacementRules[0].pattern == "c")
    }

    @Test func updateNonexistentReplacementRule() {
        let settings = Settings(defaults: makeDefaults())
        settings.addReplacementRule(ReplacementRule(pattern: "a"))

        let nonexistent = ReplacementRule(pattern: "b")
        settings.updateReplacementRule(nonexistent)

        #expect(settings.replacementRules.count == 1)
    }

    @Test func deleteReplacementRule() {
        let settings = Settings(defaults: makeDefaults())
        let rule = ReplacementRule(pattern: "a")
        settings.addReplacementRule(rule)

        settings.deleteReplacementRule(id: rule.id)

        #expect(settings.replacementRules.isEmpty)
    }

    @Test func deleteNonexistentReplacementRule() {
        let settings = Settings(defaults: makeDefaults())
        settings.addReplacementRule(ReplacementRule(pattern: "a"))

        settings.deleteReplacementRule(id: UUID())

        #expect(settings.replacementRules.count == 1)
    }

    @Test func moveReplacementRules() {
        let settings = Settings(defaults: makeDefaults())
        let a = ReplacementRule(pattern: "a")
        let b = ReplacementRule(pattern: "b")
        let c = ReplacementRule(pattern: "c")
        settings.replacementRules = [a, b, c]

        settings.moveReplacementRules(from: IndexSet(integer: 2), to: 0)

        #expect(settings.replacementRules[0].pattern == "c")
        #expect(settings.replacementRules[1].pattern == "a")
        #expect(settings.replacementRules[2].pattern == "b")
    }

    @Test func persistsReplacementRules() {
        let defaults = makeDefaults()
        let rule = ReplacementRule(
            pattern: "foo",
            replacement: "bar",
            usesRegularExpression: true,
            matchesWholeWord: false
        )

        let settings = Settings(defaults: defaults)
        settings.addReplacementRule(rule)

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.replacementRules.count == 1)
        let loaded = reloaded.replacementRules[0]
        #expect(loaded.id == rule.id)
        #expect(loaded.pattern == "foo")
        #expect(loaded.replacement == "bar")
        #expect(loaded.usesRegularExpression == true)
        #expect(loaded.matchesWholeWord == false)
    }

    @Test func corruptedReplacementRulesFallsBack() {
        let defaults = makeDefaults()
        defaults.set(Data("invalid json".utf8), forKey: "replacementRules")

        let settings = Settings(defaults: defaults)
        #expect(settings.replacementRules.isEmpty)
    }

    // MARK: - Replacement Shortcut Key

    @Test func defaultReplacementShortcutKey() {
        let settings = Settings(defaults: makeDefaults())
        #expect(settings.replacementShortcutKey == "r")
    }

    @Test func defaultAppliesReplacementRulesOnConfirm() {
        let settings = Settings(defaults: makeDefaults())
        #expect(settings.appliesReplacementRulesOnConfirm == true)
    }

    @Test func persistsReplacementShortcutKey() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.replacementShortcutKey = "x"

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.replacementShortcutKey == "x")
    }

    @Test func persistsNilReplacementShortcutKey() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.replacementShortcutKey = nil

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.replacementShortcutKey == nil)
    }

    @Test func persistsAppliesReplacementRulesOnConfirm() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.appliesReplacementRulesOnConfirm = false

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.appliesReplacementRulesOnConfirm == false)
    }

    // MARK: - History Settings

    @Test func defaultHistorySettings() {
        let settings = Settings(defaults: makeDefaults())

        #expect(settings.isHistoryEnabled == true)
        #expect(settings.historyMaxCount == 500)
        #expect(settings.historyRetentionDays == 30)
    }

    @Test func persistsHistorySettings() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.isHistoryEnabled = false
        settings.historyMaxCount = 100
        settings.historyRetentionDays = 7

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.isHistoryEnabled == false)
        #expect(reloaded.historyMaxCount == 100)
        #expect(reloaded.historyRetentionDays == 7)
    }

    @Test func clampsHistoryMaxCount() {
        let settings = Settings(defaults: makeDefaults())
        settings.historyMaxCount = 0
        #expect(settings.historyMaxCount == 1)

        settings.historyMaxCount = -5
        #expect(settings.historyMaxCount == 1)
    }

    @Test func clampsHistoryRetentionDays() {
        let settings = Settings(defaults: makeDefaults())
        settings.historyRetentionDays = 0
        #expect(settings.historyRetentionDays == 1)

        settings.historyRetentionDays = -5
        #expect(settings.historyRetentionDays == 1)
    }

    // MARK: - Hotkey Config

    @Test func defaultHotkeyConfig() {
        let settings = Settings(defaults: makeDefaults())
        #expect(settings.hotkeyConfig == .default)
        #expect(settings.hotkeyConfig.modifierKey == .fn)
        #expect(settings.hotkeyConfig.side == .left)
        #expect(settings.hotkeyConfig.tapMode == .singleToggle)
    }

    @Test func persistsHotkeyConfig() {
        let defaults = makeDefaults()

        let settings = Settings(defaults: defaults)
        settings.hotkeyConfig = HotkeyConfig(modifierKey: .command, side: .right, tapMode: .doubleTapToShow)

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.hotkeyConfig.modifierKey == .command)
        #expect(reloaded.hotkeyConfig.side == .right)
        #expect(reloaded.hotkeyConfig.tapMode == .doubleTapToShow)
    }

    @Test func fnSideCorrectedToLeft() {
        let settings = Settings(defaults: makeDefaults())
        settings.hotkeyConfig = HotkeyConfig(modifierKey: .fn, side: .right, tapMode: .singleToggle)
        #expect(settings.hotkeyConfig.side == .left)
    }

    @Test func corruptedHotkeyConfigFallsBack() {
        let defaults = makeDefaults()
        defaults.set(Data("invalid json".utf8), forKey: "hotkeyConfig")

        let settings = Settings(defaults: defaults)
        #expect(settings.hotkeyConfig == .default)
    }

}
