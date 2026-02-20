import Foundation
import SwiftUI
import os

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
    }
}
