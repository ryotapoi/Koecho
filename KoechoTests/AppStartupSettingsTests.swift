import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
struct AppStartupSettingsTests {
  @Test func hostedStartupIsolatesSettingsBeforeNormalization() throws {
    #expect(KoechoApp.isTesting)
    let normalName = "koecho-startup-normal-\(UUID().uuidString)"
    let hostedName = "koecho-startup-hosted-\(UUID().uuidString)"
    let normal = try #require(UserDefaults(suiteName: normalName))
    let hosted = try #require(UserDefaults(suiteName: hostedName))
    defer {
      normal.removePersistentDomain(forName: normalName)
      hosted.removePersistentDomain(forName: hostedName)
    }
    let fixture: [String: Any] = [
      "scriptTimeout": "invalid-timeout",
      "voiceInputMode": "dictation",
      "voiceInputShortcut": Data([0xFF]),
      "audioInputDeviceUID": "normal-only-device",
    ]
    normal.setPersistentDomain(fixture, forName: normalName)
    var accessedNormalDefaults = false
    func normalDefaults() -> UserDefaults {
      accessedNormalDefaults = true
      return normal
    }

    // Use the same default test detection and construction as the App's @State.
    let state = KoechoApp.makeInitialAppState(
      normalDefaults: normalDefaults(), testingSuiteName: hostedName
    )
    #expect(!accessedNormalDefaults)
    #expect(state.settings.script.scriptTimeout == 30)
    #expect(state.settings.voiceInput.audioInputDeviceUID == nil)
    #expect(state.settings.loadFailures.isEmpty)
    #expect(hosted.string(forKey: "voiceInputMode") == "on")
    #expect(hosted.double(forKey: "scriptTimeout") == 30)
    #expect(hosted.data(forKey: "voiceInputShortcut") == Data())

    state.settings.script.scriptTimeout = 17
    state.settings.voiceInput.isVoiceInputEnabled = false
    #expect(hosted.double(forKey: "scriptTimeout") == 17)
    #expect(hosted.string(forKey: "voiceInputMode") == "off")
    let preserved = try #require(normal.persistentDomain(forName: normalName))
    #expect(NSDictionary(dictionary: preserved).isEqual(to: fixture))
    #expect(preserved["scriptTimeout"] is String)
    #expect(preserved["voiceInputMode"] is String)
    #expect(preserved["voiceInputShortcut"] is Data)
  }

  @Test func normalStartupRetainsSettingsAndNormalization() throws {
    let suiteName = "koecho-startup-normal-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.setPersistentDomain([
      "scriptTimeout": "invalid-timeout",
      "voiceInputMode": "dictation",
      "voiceInputShortcut": Data([0xFF]),
      "audioInputDeviceUID": "normal-only-device",
    ], forName: suiteName)

    let state = KoechoApp.makeInitialAppState(isTesting: false, normalDefaults: defaults)
    #expect(state.settings.voiceInput.audioInputDeviceUID == "normal-only-device")
    #expect(state.settings.voiceInput.isVoiceInputEnabled)
    #expect(state.settings.loadFailures == [.scriptTimeout, .voiceInputShortcut])
    #expect(defaults.double(forKey: "scriptTimeout") == 30)
    #expect(defaults.string(forKey: "voiceInputMode") == "on")
    #expect(defaults.data(forKey: "voiceInputShortcut") == Data())
    state.settings.script.scriptTimeout = 19
    #expect(defaults.double(forKey: "scriptTimeout") == 19)
  }
}
