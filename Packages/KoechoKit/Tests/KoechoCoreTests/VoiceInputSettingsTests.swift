import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct VoiceInputSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func defaultVoiceInputMode() {
        let settings = VoiceInputSettings(defaults: makeDefaults())
        if #available(macOS 26, *) {
            #expect(settings.voiceInputMode == .speechAnalyzer)
        } else {
            #expect(settings.voiceInputMode == .dictation)
        }
    }

    @Test func persistsVoiceInputMode() {
        let defaults = makeDefaults()

        let settings = VoiceInputSettings(defaults: defaults)
        settings.voiceInputMode = .speechAnalyzer

        let reloaded = VoiceInputSettings(defaults: defaults)
        #expect(reloaded.voiceInputMode == .speechAnalyzer)
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
        #expect(VoiceInputSettings.systemSpeechAnalyzerLocale(preferredLanguage: "zh-Hant-TW") == "zh-Hant-TW")
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

    @Test func persistsOffMode() {
        let defaults = makeDefaults()

        let settings = VoiceInputSettings(defaults: defaults)
        settings.voiceInputMode = .off

        let reloaded = VoiceInputSettings(defaults: defaults)
        #expect(reloaded.voiceInputMode == .off)
    }

    @Test func offModeCycle() {
        let defaults = makeDefaults()
        let settings = VoiceInputSettings(defaults: defaults)

        settings.voiceInputMode = .off
        #expect(settings.effectiveVoiceInputMode == .off)

        settings.voiceInputMode = .dictation
        #expect(settings.effectiveVoiceInputMode == .dictation)

        let reloaded = VoiceInputSettings(defaults: defaults)
        #expect(reloaded.voiceInputMode == .dictation)
    }

    @Test func migratesLegacyVoiceInputDisabled() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "isVoiceInputEnabled")
        defaults.set("speechAnalyzer", forKey: "voiceInputMode")

        let settings = VoiceInputSettings(defaults: defaults)
        #expect(settings.voiceInputMode == .off)
        #expect(defaults.object(forKey: "isVoiceInputEnabled") == nil)
    }

    @Test func legacyVoiceInputEnabledTrueDoesNotMigrate() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "isVoiceInputEnabled")
        defaults.set("speechAnalyzer", forKey: "voiceInputMode")

        let settings = VoiceInputSettings(defaults: defaults)
        #expect(settings.voiceInputMode == .speechAnalyzer)
    }

    @Test func effectiveVoiceInputModeOffPreserved() {
        let settings = VoiceInputSettings(defaults: makeDefaults())
        settings.voiceInputMode = .off
        #expect(settings.effectiveVoiceInputMode == .off)
    }

    @Test func effectiveVoiceInputModeFallsToDictation() {
        let settings = VoiceInputSettings(defaults: makeDefaults())
        settings.voiceInputMode = .speechAnalyzer

        if #available(macOS 26, *) {
            #expect(settings.effectiveVoiceInputMode == .speechAnalyzer)
        } else {
            #expect(settings.effectiveVoiceInputMode == .dictation)
        }
    }
}
