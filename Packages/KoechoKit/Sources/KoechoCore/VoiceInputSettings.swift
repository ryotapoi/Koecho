import Foundation
import Observation

@MainActor @Observable
public final class VoiceInputSettings {
  private let defaults: UserDefaults

  private var _isVoiceInputEnabled: Bool
  public var isVoiceInputEnabled: Bool {
    get { _isVoiceInputEnabled }
    set {
      _isVoiceInputEnabled = newValue
      save()
    }
  }

  private var _speechAnalyzerLocale: String
  public var speechAnalyzerLocale: String {
    get { _speechAnalyzerLocale }
    set {
      _speechAnalyzerLocale = newValue
      save()
    }
  }

  private var _audioInputDeviceUID: String?
  public var audioInputDeviceUID: String? {
    get { _audioInputDeviceUID }
    set {
      _audioInputDeviceUID = newValue
      save()
    }
  }

  private var _audioInputDeviceName: String?
  public var audioInputDeviceName: String? {
    get { _audioInputDeviceName }
    set {
      _audioInputDeviceName = newValue
      save()
    }
  }

  public init(defaults: UserDefaults) {
    self.defaults = defaults

    _isVoiceInputEnabled = Self.voiceInputEnabled(
      from: defaults.string(forKey: "voiceInputMode")
    )

    _speechAnalyzerLocale =
      defaults.string(forKey: "speechAnalyzerLocale")
      ?? Self.systemSpeechAnalyzerLocale()
    _audioInputDeviceUID = defaults.string(forKey: "audioInputDeviceUID")
    _audioInputDeviceName = defaults.string(forKey: "audioInputDeviceName")

    save()
  }

  nonisolated public static func systemSpeechAnalyzerLocale(
    preferredLanguage: String? = Locale.preferredLanguages.first
  ) -> String {
    guard let preferred = preferredLanguage, !preferred.isEmpty else {
      return "en-US"
    }
    return preferred.replacing("_", with: "-")
  }

  nonisolated private static func voiceInputEnabled(from rawValue: String?) -> Bool {
    switch rawValue {
    case "off": false
    case "dictation", "speechAnalyzer", "on", nil: true
    default: true
    }
  }

  private func save() {
    defaults.set(_isVoiceInputEnabled ? "on" : "off", forKey: "voiceInputMode")
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
