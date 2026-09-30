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

  @Test func corruptedReplacementRulesRemainProtectedUntilExplicitReset() {
    let defaults = makeDefaults()
    let original = Data("invalid json".utf8)
    defaults.set(original, forKey: "replacementRules")

    let settings = ReplacementSettings(defaults: defaults)
    #expect(settings.replacementRules.isEmpty)
    #expect(settings.isReplacementRulesProtected)
    #expect(settings.loadFailures == [.replacementRules])
    #expect(defaults.object(forKey: "replacementRules") as? Data == original)

    settings.isAutoReplacementEnabled = false
    settings.addReplacementRule(ReplacementRule(pattern: "ignored"))
    settings.moveReplacementRules(from: IndexSet(), to: 0)
    #expect(defaults.object(forKey: "replacementRules") as? Data == original)

    let reloaded = ReplacementSettings(defaults: defaults)
    #expect(reloaded.isReplacementRulesProtected)
    #expect(reloaded.replacementRules.isEmpty)
    #expect(defaults.object(forKey: "replacementRules") as? Data == original)
  }

  @Test func resetReplacementRulesDiscardsProtectedData() throws {
    let defaults = makeDefaults()
    defaults.set(Data("invalid json".utf8), forKey: "replacementRules")
    let settings = ReplacementSettings(defaults: defaults)

    settings.resetReplacementRules()

    #expect(!settings.isReplacementRulesProtected)
    let data = try #require(defaults.data(forKey: "replacementRules"))
    #expect(try JSONDecoder().decode([ReplacementRule].self, from: data).isEmpty)
    let reloaded = ReplacementSettings(defaults: defaults)
    #expect(reloaded.replacementRules.isEmpty)
  }

  @Test func nonDataReplacementRulesRemainProtectedWhenOtherSettingsChange() {
    let defaults = makeDefaults()
    let original = "not rule data"
    defaults.set(original, forKey: "replacementRules")
    let settings = ReplacementSettings(defaults: defaults)

    settings.isAutoReplacementEnabled = false

    #expect(settings.isReplacementRulesProtected)
    #expect(defaults.object(forKey: "replacementRules") as? String == original)
    #expect(defaults.object(forKey: "isAutoReplacementEnabled") as? Bool == false)
  }

  @Test func malformedReplacementScalarsAreRecordedAndDefaulted() {
    let defaults = makeDefaults()
    defaults.set("not shortcut data", forKey: "replacementShortcut")
    defaults.set("not a boolean", forKey: "isAutoReplacementEnabled")

    let settings = ReplacementSettings(defaults: defaults)

    #expect(settings.replacementShortcutKey == ReplacementSettings.defaultReplacementShortcutKey)
    #expect(settings.isAutoReplacementEnabled)
    #expect(settings.loadFailures == [.replacementShortcut, .isAutoReplacementEnabled])

    settings.isAutoReplacementEnabled = false
    let reloaded = ReplacementSettings(defaults: defaults)
    #expect(!reloaded.isAutoReplacementEnabled)
  }

  @Test func defaultReplacementShortcutKey() {
    let settings = ReplacementSettings(defaults: makeDefaults())
    #expect(settings.replacementShortcutKey == ReplacementSettings.defaultReplacementShortcutKey)
  }

  @Test func emptyReplacementShortcutDataRemainsDisabled() {
    let defaults = makeDefaults()
    defaults.set(Data(), forKey: "replacementShortcut")

    let settings = ReplacementSettings(defaults: defaults)

    #expect(settings.replacementShortcutKey == nil)
  }

  @Test func corruptReplacementShortcutDataUsesDefault() {
    let defaults = makeDefaults()
    defaults.set(Data("invalid json".utf8), forKey: "replacementShortcut")

    let settings = ReplacementSettings(defaults: defaults)

    #expect(settings.replacementShortcutKey == ReplacementSettings.defaultReplacementShortcutKey)
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

  // MARK: - Legacy format rejection

  @Test func doesNotMigrateLegacyFormatToPatterns() throws {
    let defaults = makeDefaults()
    let legacyJSON = """
      [{
          "id": "00000000-0000-0000-0000-000000000001",
          "pattern": "test",
          "replacement": "replaced",
          "usesRegularExpression": false,
          "matchesWholeWord": false
      }]
      """.data(using: .utf8)!
    defaults.set(legacyJSON, forKey: "replacementRules")

    let settings = ReplacementSettings(defaults: defaults)

    #expect(settings.replacementRules.isEmpty)
    #expect(settings.isReplacementRulesProtected)

    // Loading an unsupported format must retain its original bytes.
    let data = defaults.data(forKey: "replacementRules")!
    #expect(data == legacyJSON)
  }
}
