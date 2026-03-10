import Foundation

enum VoiceInputMode: String, Codable, CaseIterable {
    case dictation
    case speechAnalyzer
}

@MainActor @Observable
final class VoiceInputSettings {
    private let defaults: UserDefaults

    private var _voiceInputMode: VoiceInputMode
    var voiceInputMode: VoiceInputMode {
        get { _voiceInputMode }
        set {
            _voiceInputMode = newValue
            save()
        }
    }

    private var _speechAnalyzerLocale: String
    var speechAnalyzerLocale: String {
        get { _speechAnalyzerLocale }
        set {
            _speechAnalyzerLocale = newValue
            save()
        }
    }

    private var _audioInputDeviceUID: String?
    var audioInputDeviceUID: String? {
        get { _audioInputDeviceUID }
        set {
            _audioInputDeviceUID = newValue
            save()
        }
    }

    private var _audioInputDeviceName: String?
    var audioInputDeviceName: String? {
        get { _audioInputDeviceName }
        set {
            _audioInputDeviceName = newValue
            save()
        }
    }

    var effectiveVoiceInputMode: VoiceInputMode {
        if #available(macOS 26, *) { return _voiceInputMode }
        return .dictation
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults

        if let rawMode = defaults.string(forKey: "voiceInputMode"),
           let mode = VoiceInputMode(rawValue: rawMode) {
            _voiceInputMode = mode
        } else {
            if #available(macOS 26, *) {
                _voiceInputMode = .speechAnalyzer
            } else {
                _voiceInputMode = .dictation
            }
        }

        _speechAnalyzerLocale = defaults.string(forKey: "speechAnalyzerLocale")
            ?? Self.systemSpeechAnalyzerLocale()
        _audioInputDeviceUID = defaults.string(forKey: "audioInputDeviceUID")
        _audioInputDeviceName = defaults.string(forKey: "audioInputDeviceName")

        save()
    }

    nonisolated static func systemSpeechAnalyzerLocale(
        preferredLanguage: String? = Locale.preferredLanguages.first
    ) -> String {
        guard let preferred = preferredLanguage, !preferred.isEmpty else {
            return "en-US"
        }
        return preferred.replacingOccurrences(of: "_", with: "-")
    }

    private func save() {
        defaults.set(_voiceInputMode.rawValue, forKey: "voiceInputMode")
        defaults.set(_speechAnalyzerLocale, forKey: "speechAnalyzerLocale")
        if let uid = _audioInputDeviceUID {
            defaults.set(uid, forKey: "audioInputDeviceUID")
        } else {
            defaults.removeObject(forKey: "audioInputDeviceUID")
        }
        if let name = _audioInputDeviceName {
            defaults.set(name, forKey: "audioInputDeviceName")
        } else {
            defaults.removeObject(forKey: "audioInputDeviceName")
        }
    }
}
