import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct ReplacementSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultReplacementRulesEmpty() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        #expect(settings.replacementRules.isEmpty)
    }

    @Test func addReplacementRule() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        let rule = ReplacementRule(pattern: "えーと", replacement: "")

        settings.addReplacementRule(rule)

        #expect(settings.replacementRules.count == 1)
        #expect(settings.replacementRules[0].id == rule.id)
    }

    @Test func updateReplacementRule() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        var rule = ReplacementRule(pattern: "a", replacement: "b")
        settings.addReplacementRule(rule)

        rule.pattern = "c"
        settings.updateReplacementRule(rule)

        #expect(settings.replacementRules.count == 1)
        #expect(settings.replacementRules[0].pattern == "c")
    }

    @Test func updateNonexistentReplacementRule() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        settings.addReplacementRule(ReplacementRule(pattern: "a"))

        let nonexistent = ReplacementRule(pattern: "b")
        settings.updateReplacementRule(nonexistent)

        #expect(settings.replacementRules.count == 1)
    }

    @Test func deleteReplacementRule() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        let rule = ReplacementRule(pattern: "a")
        settings.addReplacementRule(rule)

        settings.deleteReplacementRule(id: rule.id)

        #expect(settings.replacementRules.isEmpty)
    }

    @Test func deleteNonexistentReplacementRule() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        settings.addReplacementRule(ReplacementRule(pattern: "a"))

        settings.deleteReplacementRule(id: UUID())

        #expect(settings.replacementRules.count == 1)
    }

    @Test func moveReplacementRules() {
        let settings = ReplacementSettings(defaults: makeDefaults())
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

        let settings = ReplacementSettings(defaults: defaults)
        settings.addReplacementRule(rule)

        let reloaded = ReplacementSettings(defaults: defaults)
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

        let settings = ReplacementSettings(defaults: defaults)
        #expect(settings.replacementRules.isEmpty)
    }

    @Test func defaultReplacementShortcutKey() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        #expect(settings.replacementShortcutKey == ShortcutKey(modifiers: [.control], character: "r"))
    }

    @Test func defaultAutoReplacementEnabled() {
        let settings = ReplacementSettings(defaults: makeDefaults())
        #expect(settings.isAutoReplacementEnabled == true)
    }

    @Test func persistsReplacementShortcutKey() {
        let defaults = makeDefaults()

        let settings = ReplacementSettings(defaults: defaults)
        settings.replacementShortcutKey = ShortcutKey(modifiers: [.command], character: "x")

        let reloaded = ReplacementSettings(defaults: defaults)
        #expect(reloaded.replacementShortcutKey == ShortcutKey(modifiers: [.command], character: "x"))
    }

    @Test func persistsNilReplacementShortcutKey() {
        let defaults = makeDefaults()

        let settings = ReplacementSettings(defaults: defaults)
        settings.replacementShortcutKey = nil

        let reloaded = ReplacementSettings(defaults: defaults)
        #expect(reloaded.replacementShortcutKey == nil)
    }

    @Test func persistsAutoReplacementEnabled() {
        let defaults = makeDefaults()

        let settings = ReplacementSettings(defaults: defaults)
        settings.isAutoReplacementEnabled = false

        let reloaded = ReplacementSettings(defaults: defaults)
        #expect(reloaded.isAutoReplacementEnabled == false)
    }
}
