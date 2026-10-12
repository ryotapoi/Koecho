import Foundation
import Testing

@testable import KoechoCore

@MainActor
struct SettingsTests {

  @Test @MainActor func aggregatesLoadFailuresInStableKeyOrder() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    defaults.set(Data("invalid json".utf8), forKey: "scripts")
    defaults.set("not a boolean", forKey: "isAutoReplacementEnabled")
    defaults.set(Data("invalid json".utf8), forKey: "replacementRules")

    let settings = Settings(defaults: defaults)

    #expect(settings.orderedLoadFailures == [.scripts, .replacementRules, .isAutoReplacementEnabled])
  }
  private func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
  }

  @Test func roundTripViaSubSettings() {
    let defaults = makeDefaults()

    let settings = Settings(defaults: defaults)
    settings.paste.pasteDelay = 5.0
    settings.script.scriptTimeout = 60.0
    settings.history.isHistoryEnabled = false
    settings.volumeDucking.isVolumeDuckingEnabled = true

    let reloaded = Settings(defaults: defaults)
    #expect(reloaded.paste.pasteDelay == 5.0)
    #expect(reloaded.script.scriptTimeout == 60.0)
    #expect(reloaded.history.isHistoryEnabled == false)
    #expect(reloaded.volumeDucking.isVolumeDuckingEnabled == true)
  }

  @Test func subSettingsShareSameDefaults() {
    let defaults = makeDefaults()
    let settings = Settings(defaults: defaults)

    // Modify via sub-settings
    settings.script.addScript(Script(name: "Test", scriptPath: "/bin/test"))
    settings.replacement.addReplacementRule(ReplacementRule(pattern: "a", replacement: "b"))

    // Reload via fresh Settings (same defaults) and verify
    let reloaded = Settings(defaults: defaults)
    #expect(reloaded.script.scripts.count == Script.defaultBuiltins.count + 1)
    #expect(reloaded.script.scripts.last?.name == "Test")
    #expect(reloaded.replacement.replacementRules.count == 1)
  }
}
