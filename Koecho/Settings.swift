import Foundation
import SwiftUI
import os

enum VoiceInputMode: String, Codable, CaseIterable {
    case dictation
    case speechAnalyzer
}

@MainActor @Observable
final class Settings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "Settings")

    private var _pasteDelay: TimeInterval
    var pasteDelay: TimeInterval {
        get { _pasteDelay }
        set {
            _pasteDelay = max(0, newValue)
            save()
        }
    }

    private var _scriptTimeout: TimeInterval
    var scriptTimeout: TimeInterval {
        get { _scriptTimeout }
        set {
            _scriptTimeout = max(1, newValue)
            save()
        }
    }

    private var _replacementShortcutKey: ShortcutKey?
    var replacementShortcutKey: ShortcutKey? {
        get { _replacementShortcutKey }
        set {
            _replacementShortcutKey = newValue
            save()
        }
    }

    private var _isAutoReplacementEnabled: Bool
    var isAutoReplacementEnabled: Bool {
        get { _isAutoReplacementEnabled }
        set {
            _isAutoReplacementEnabled = newValue
            save()
        }
    }

    private var _isHistoryEnabled: Bool
    var isHistoryEnabled: Bool {
        get { _isHistoryEnabled }
        set {
            _isHistoryEnabled = newValue
            save()
        }
    }

    private var _historyMaxCount: Int
    var historyMaxCount: Int {
        get { _historyMaxCount }
        set {
            _historyMaxCount = max(1, newValue)
            save()
        }
    }

    private var _historyRetentionDays: Int
    var historyRetentionDays: Int {
        get { _historyRetentionDays }
        set {
            _historyRetentionDays = max(1, newValue)
            save()
        }
    }

    var scripts: [Script] {
        didSet { save() }
    }

    var replacementRules: [ReplacementRule] {
        didSet { save() }
    }

    private var _autoRunScriptId: UUID?
    var autoRunScriptId: UUID? {
        get { _autoRunScriptId }
        set {
            _autoRunScriptId = newValue
            save()
        }
    }

    private var _autoRunShortcutKey: ShortcutKey?
    var autoRunShortcutKey: ShortcutKey? {
        get { _autoRunShortcutKey }
        set {
            _autoRunShortcutKey = newValue
            save()
        }
    }

    var autoRunScript: Script? {
        guard let id = autoRunScriptId else { return nil }
        return scripts.first { $0.id == id && !$0.requiresPrompt }
    }

    private var _hotkeyConfig: HotkeyConfig
    var hotkeyConfig: HotkeyConfig {
        get { _hotkeyConfig }
        set {
            var corrected = newValue
            if corrected.modifierKey == .fn {
                corrected.side = .left
            }
            _hotkeyConfig = corrected
            save()
        }
    }

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

    private var _isVolumeDuckingEnabled: Bool
    var isVolumeDuckingEnabled: Bool {
        get { _isVolumeDuckingEnabled }
        set {
            _isVolumeDuckingEnabled = newValue
            save()
        }
    }

    private var _volumeDuckingLevel: Float
    var volumeDuckingLevel: Float {
        get { _volumeDuckingLevel }
        set {
            _volumeDuckingLevel = max(0, min(1, newValue))
            save()
        }
    }

    /// Returns the effective voice input mode considering OS availability.
    var effectiveVoiceInputMode: VoiceInputMode {
        if #available(macOS 26, *) { return _voiceInputMode }
        return .dictation
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        _pasteDelay = max(0, defaults.object(forKey: "pasteDelay") as? TimeInterval ?? 2.0)
        _scriptTimeout = max(1, defaults.object(forKey: "scriptTimeout") as? TimeInterval ?? 30.0)

        if let data = defaults.data(forKey: "replacementShortcut") {
            if data.isEmpty {
                _replacementShortcutKey = nil
            } else if let decoded = try? JSONDecoder().decode(ShortcutKey.self, from: data) {
                _replacementShortcutKey = decoded
            } else {
                logger.warning("Failed to decode replacementShortcut, using default")
                _replacementShortcutKey = ShortcutKey(modifiers: [.control], character: "r")
            }
        } else {
            _replacementShortcutKey = ShortcutKey(modifiers: [.control], character: "r")
        }

        _isAutoReplacementEnabled = defaults.object(forKey: "isAutoReplacementEnabled") as? Bool ?? true

        _isHistoryEnabled = defaults.object(forKey: "isHistoryEnabled") as? Bool ?? true
        _historyMaxCount = max(1, defaults.object(forKey: "historyMaxCount") as? Int ?? 500)
        _historyRetentionDays = max(1, defaults.object(forKey: "historyRetentionDays") as? Int ?? 30)

        if let data = defaults.data(forKey: "scripts") {
            do {
                scripts = try JSONDecoder().decode([Script].self, from: data)
            } catch {
                logger.warning("Failed to decode scripts, using defaults: \(error.localizedDescription)")
                scripts = []
            }
        } else {
            scripts = []
        }

        if let data = defaults.data(forKey: "replacementRules") {
            do {
                replacementRules = try JSONDecoder().decode([ReplacementRule].self, from: data)
            } catch {
                logger.warning("Failed to decode replacement rules, using defaults: \(error.localizedDescription)")
                replacementRules = []
            }
        } else {
            replacementRules = []
        }

        if let uuidString = defaults.string(forKey: "autoRunScriptId") {
            _autoRunScriptId = UUID(uuidString: uuidString)
        } else {
            _autoRunScriptId = nil
        }

        if let data = defaults.data(forKey: "autoRunShortcut") {
            if data.isEmpty {
                _autoRunShortcutKey = nil
            } else if let decoded = try? JSONDecoder().decode(ShortcutKey.self, from: data) {
                _autoRunShortcutKey = decoded
            } else {
                logger.warning("Failed to decode autoRunShortcut, using nil")
                _autoRunShortcutKey = nil
            }
        } else {
            _autoRunShortcutKey = nil
        }

        if let data = defaults.data(forKey: "hotkeyConfig") {
            do {
                _hotkeyConfig = try JSONDecoder().decode(HotkeyConfig.self, from: data)
            } catch {
                logger.warning("Failed to decode hotkey config, using defaults: \(error.localizedDescription)")
                _hotkeyConfig = .default
            }
        } else {
            _hotkeyConfig = .default
        }

        if let rawMode = defaults.string(forKey: "voiceInputMode"),
           let mode = VoiceInputMode(rawValue: rawMode) {
            _voiceInputMode = mode
        } else {
            _voiceInputMode = .dictation
        }

        _speechAnalyzerLocale = defaults.string(forKey: "speechAnalyzerLocale") ?? "ja-JP"
        _audioInputDeviceUID = defaults.string(forKey: "audioInputDeviceUID")
        _audioInputDeviceName = defaults.string(forKey: "audioInputDeviceName")

        _isVolumeDuckingEnabled = defaults.object(forKey: "isVolumeDuckingEnabled") as? Bool ?? false
        _volumeDuckingLevel = max(0, min(1, defaults.object(forKey: "volumeDuckingLevel") as? Float ?? 0.05))

        save()
    }

    func addScript(_ script: Script) {
        scripts.append(script)
    }

    func updateScript(_ script: Script) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
    }

    func deleteScript(id: UUID) {
        scripts.removeAll { $0.id == id }
        if autoRunScriptId == id {
            autoRunScriptId = nil
        }
    }

    func moveScripts(from source: IndexSet, to destination: Int) {
        scripts.move(fromOffsets: source, toOffset: destination)
    }

    func addReplacementRule(_ rule: ReplacementRule) {
        replacementRules.append(rule)
    }

    func updateReplacementRule(_ rule: ReplacementRule) {
        guard let index = replacementRules.firstIndex(where: { $0.id == rule.id }) else { return }
        replacementRules[index] = rule
    }

    func deleteReplacementRule(id: UUID) {
        replacementRules.removeAll { $0.id == id }
    }

    func moveReplacementRules(from source: IndexSet, to destination: Int) {
        replacementRules.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        defaults.set(_pasteDelay, forKey: "pasteDelay")
        defaults.set(_scriptTimeout, forKey: "scriptTimeout")
        if let shortcut = _replacementShortcutKey {
            defaults.set(try? JSONEncoder().encode(shortcut), forKey: "replacementShortcut")
        } else {
            defaults.set(Data(), forKey: "replacementShortcut")
        }
        if let id = _autoRunScriptId {
            defaults.set(id.uuidString, forKey: "autoRunScriptId")
        } else {
            defaults.removeObject(forKey: "autoRunScriptId")
        }
        if let shortcut = _autoRunShortcutKey {
            defaults.set(try? JSONEncoder().encode(shortcut), forKey: "autoRunShortcut")
        } else {
            defaults.set(Data(), forKey: "autoRunShortcut")
        }
        defaults.set(_isAutoReplacementEnabled, forKey: "isAutoReplacementEnabled")
        defaults.set(_isHistoryEnabled, forKey: "isHistoryEnabled")
        defaults.set(_historyMaxCount, forKey: "historyMaxCount")
        defaults.set(_historyRetentionDays, forKey: "historyRetentionDays")
        do {
            let data = try JSONEncoder().encode(scripts)
            defaults.set(data, forKey: "scripts")
        } catch {
            logger.error("Failed to encode scripts: \(error.localizedDescription)")
        }
        do {
            let data = try JSONEncoder().encode(replacementRules)
            defaults.set(data, forKey: "replacementRules")
        } catch {
            logger.error("Failed to encode replacement rules: \(error.localizedDescription)")
        }
        do {
            let data = try JSONEncoder().encode(_hotkeyConfig)
            defaults.set(data, forKey: "hotkeyConfig")
        } catch {
            logger.error("Failed to encode hotkey config: \(error.localizedDescription)")
        }
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
        defaults.set(_isVolumeDuckingEnabled, forKey: "isVolumeDuckingEnabled")
        defaults.set(_volumeDuckingLevel, forKey: "volumeDuckingLevel")
    }
}
