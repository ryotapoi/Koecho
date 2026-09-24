import Foundation
import Testing

@testable import KoechoCore

@MainActor
struct VoiceInputSettingsTests {
  private func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
  }

  @Test func voiceInputIsEnabledByDefaultAndStoredCanonically() {
    let settings = VoiceInputSettings(defaults: makeDefaults())
    #expect(settings.isVoiceInputEnabled)
  }

  @Test func voiceShortcutDefaultsToNilAndRoundTripsClearing() {
    let defaults = makeDefaults()
    let key = ShortcutKey(modifiers: [.control], character: "v")
    let settings = VoiceInputSettings(defaults: defaults)
    #expect(settings.voiceInputShortcutKey == nil)
    settings.voiceInputShortcutKey = key
    #expect(VoiceInputSettings(defaults: defaults).voiceInputShortcutKey == key)
    settings.voiceInputShortcutKey = nil
    #expect(VoiceInputSettings(defaults: defaults).voiceInputShortcutKey == nil)
  }

  @Test func malformedVoiceShortcutIsReportedAndReset() {
    let defaults = makeDefaults()
    defaults.set(Data("invalid".utf8), forKey: "voiceInputShortcut")
    let settings = Settings(defaults: defaults)
    #expect(settings.voiceInput.voiceInputShortcutKey == nil)
    #expect(settings.loadFailures.contains(.voiceInputShortcut))
    #expect(defaults.data(forKey: "voiceInputShortcut") == Data())
  }

  @Test func persistsVoiceInputEnabled() {
    let defaults = makeDefaults()

    let settings = VoiceInputSettings(defaults: defaults)
    settings.isVoiceInputEnabled = false

    let reloaded = VoiceInputSettings(defaults: defaults)
    #expect(!reloaded.isVoiceInputEnabled)
    #expect(defaults.string(forKey: "voiceInputMode") == "off")
  }

  @Test func defaultSpeechAnalyzerLocale() {
    let settings = VoiceInputSettings(defaults: makeDefaults())
    #expect(settings.speechAnalyzerLocale == VoiceInputSettings.systemSpeechAnalyzerLocale())
  }

  @Test func persistsSpeechAnalyzerLocale() {
    let defaults = makeDefaults()

    let settings = VoiceInputSettings(defaults: defaults)
    settings.speechAnalyzerLocale = "en-US"

    let reloaded = VoiceInputSettings(defaults: defaults)
    #expect(reloaded.speechAnalyzerLocale == "en-US")
  }

  @Test func systemSpeechAnalyzerLocaleMapping() {
    #expect(VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: "ja-JP") == "ja-JP")
    #expect(VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: "en-US") == "en-US")
    #expect(
      VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: "zh-Hant-TW") == "zh-Hant-TW"
    )
    #expect(VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: "en_US") == "en-US")
    #expect(VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: "") == "en-US")
    #expect(VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: nil) == "en-US")
  }

  @Test func defaultAudioInputDeviceUID() {
    let settings = VoiceInputSettings(defaults: makeDefaults())
    #expect(settings.audioInputDeviceUID == nil)
  }

  @Test func persistsAudioInputDeviceUID() {
    let defaults = makeDefaults()

    let settings = VoiceInputSettings(defaults: defaults)
    settings.audioInputDeviceUID = "BuiltInMicrophoneDevice"

    let reloaded = VoiceInputSettings(defaults: defaults)
    #expect(reloaded.audioInputDeviceUID == "BuiltInMicrophoneDevice")
  }

  @Test func persistsNilAudioInputDeviceUID() {
    let defaults = makeDefaults()

    let settings = VoiceInputSettings(defaults: defaults)
    settings.audioInputDeviceUID = "SomeDevice"
    settings.audioInputDeviceUID = nil

    let reloaded = VoiceInputSettings(defaults: defaults)
    #expect(reloaded.audioInputDeviceUID == nil)
  }

  @Test func defaultAudioInputDeviceName() {
    let settings = VoiceInputSettings(defaults: makeDefaults())
    #expect(settings.audioInputDeviceName == nil)
  }

  @Test func persistsAudioInputDeviceName() {
    let defaults = makeDefaults()
    let settings = VoiceInputSettings(defaults: defaults)
    settings.audioInputDeviceName = "AirPods Pro"
    let reloaded = VoiceInputSettings(defaults: defaults)
    #expect(reloaded.audioInputDeviceName == "AirPods Pro")
  }

  @Test func persistsNilAudioInputDeviceName() {
    let defaults = makeDefaults()
    let settings = VoiceInputSettings(defaults: defaults)
    settings.audioInputDeviceName = "AirPods Pro"
    settings.audioInputDeviceName = nil
    let reloaded = VoiceInputSettings(defaults: defaults)
    #expect(reloaded.audioInputDeviceName == nil)
  }

  @Test(arguments: ["dictation", "speechAnalyzer", "on"])
  func migratesEnabledValuesToOn(_ rawValue: String) {
    let defaults = makeDefaults()
    defaults.set(rawValue, forKey: "voiceInputMode")

    let settings = VoiceInputSettings(defaults: defaults)

    #expect(settings.isVoiceInputEnabled)
    #expect(defaults.string(forKey: "voiceInputMode") == "on")
  }

  @Test func migratesOffValueToOff() {
    let defaults = makeDefaults()
    defaults.set("off", forKey: "voiceInputMode")

    let settings = VoiceInputSettings(defaults: defaults)

    #expect(!settings.isVoiceInputEnabled)
    #expect(defaults.string(forKey: "voiceInputMode") == "off")
  }

  @Test(arguments: [nil, "unexpected"])
  func migratesMissingAndUnknownValuesToOn(_ rawValue: String?) {
    let defaults = makeDefaults()
    if let rawValue { defaults.set(rawValue, forKey: "voiceInputMode") }

    let settings = VoiceInputSettings(defaults: defaults)

    #expect(settings.isVoiceInputEnabled)
    #expect(defaults.string(forKey: "voiceInputMode") == "on")
  }

}
