import Foundation
import Testing

@testable import KoechoCore

@MainActor
struct AppIconSettingsTests {
  private func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
  }

  @Test func defaultsToCurrentIcon() {
    let settings = AppIconSettings(defaults: makeDefaults())

    #expect(settings.selectedAppIcon == .current)
  }

  @Test func persistsSelectedIcon() {
    let defaults = makeDefaults()

    let settings = AppIconSettings(defaults: defaults)
    settings.selectedAppIcon = .legacy

    let reloaded = AppIconSettings(defaults: defaults)
    #expect(reloaded.selectedAppIcon == .legacy)
  }

  @Test func invalidStoredIconFallsBackToCurrent() {
    let defaults = makeDefaults()
    defaults.set("missing", forKey: "selectedAppIcon")

    let settings = AppIconSettings(defaults: defaults)

    #expect(settings.selectedAppIcon == .current)
  }
}
