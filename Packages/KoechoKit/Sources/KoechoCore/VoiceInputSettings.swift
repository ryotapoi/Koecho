import Foundation
import Observation
import os

@MainActor @Observable
public final class VoiceInputSettings {
  private let defaults: UserDefaults
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "VoiceInputSettings")
  public private(set) var loadFailures: Set<SettingsLoadFailure> = []

  private var _voiceInputShortcutKey: ShortcutKey?
  public var voiceInputShortcutKey: ShortcutKey? {
    get { _voiceInputShortcutKey }
    set {
      _voiceInputShortcutKey = newValue
      save()
    }
  }

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
    _voiceInputShortcutKey = nil

    _isVoiceInputEnabled = Self.voiceInputEnabled(
      from: defaults.string(forKey: "voiceInputMode")
    )

    _speechAnalyzerLocale =
      defaults.string(forKey: "speechAnalyzerLocale")
      ?? Self.systemSpeechAnalyzerLocale()
    _audioInputDeviceUID = defaults.string(forKey: "audioInputDeviceUID")
    _audioInputDeviceName = defaults.string(forKey: "audioInputDeviceName")

    if let storedShortcut = defaults.object(forKey: "voiceInputShortcut") {
      if let data = storedShortcut as? Data {
        do {
          _voiceInputShortcutKey = try ShortcutKey.decodeOptional(from: data)
        } catch {
          logger.warning("Failed to decode voiceInputShortcut, using nil")
          loadFailures.insert(.voiceInputShortcut)
        }
      } else {
        loadFailures.insert(.voiceInputShortcut)
      }
    } else {
      _voiceInputShortcutKey = ShortcutKey(modifiers: [.control], character: "v")
    }

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
    do {
      defaults.set(try ShortcutKey.encodeOptional(_voiceInputShortcutKey), forKey: "voiceInputShortcut")
    } catch {
      logger.error("Failed to encode voiceInputShortcut: \(error.localizedDescription)")
    }
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
