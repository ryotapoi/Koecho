import Foundation
import SwiftUI
import os

@MainActor @Observable
final class ReplacementSettings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "ReplacementSettings")

    private var _replacementRules: [ReplacementRule]
    var replacementRules: [ReplacementRule] {
        get { _replacementRules }
        set { _replacementRules = newValue; save() }
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

    init(defaults: UserDefaults) {
        self.defaults = defaults

        if let data = defaults.data(forKey: "replacementRules") {
            do {
                _replacementRules = try JSONDecoder().decode([ReplacementRule].self, from: data)
            } catch {
                logger.warning("Failed to decode replacement rules, using defaults: \(error.localizedDescription)")
                _replacementRules = []
            }
        } else {
            _replacementRules = []
        }

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

        save()
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
        do {
            let data = try JSONEncoder().encode(_replacementRules)
            defaults.set(data, forKey: "replacementRules")
        } catch {
            logger.error("Failed to encode replacement rules: \(error.localizedDescription)")
        }
        if let shortcut = _replacementShortcutKey {
            defaults.set(try? JSONEncoder().encode(shortcut), forKey: "replacementShortcut")
        } else {
            defaults.set(Data(), forKey: "replacementShortcut")
        }
        defaults.set(_isAutoReplacementEnabled, forKey: "isAutoReplacementEnabled")
    }
}
