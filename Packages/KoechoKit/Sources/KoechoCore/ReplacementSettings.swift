import Foundation
import Observation
import os

@MainActor @Observable
public final class ReplacementSettings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ReplacementSettings")

    private var _replacementRules: [ReplacementRule]
    public var replacementRules: [ReplacementRule] {
        get { _replacementRules }
        set { _replacementRules = newValue; save() }
    }

    private var _replacementShortcutKey: ShortcutKey?
    public var replacementShortcutKey: ShortcutKey? {
        get { _replacementShortcutKey }
        set {
            _replacementShortcutKey = newValue
            save()
        }
    }

    private var _isAutoReplacementEnabled: Bool
    public var isAutoReplacementEnabled: Bool {
        get { _isAutoReplacementEnabled }
        set {
            _isAutoReplacementEnabled = newValue
            save()
        }
    }

    public init(defaults: UserDefaults) {
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

    public func addReplacementRule(_ rule: ReplacementRule) {
        replacementRules.append(rule)
    }

    public func updateReplacementRule(_ rule: ReplacementRule) {
        guard let index = replacementRules.firstIndex(where: { $0.id == rule.id }) else { return }
        replacementRules[index] = rule
    }

    public func deleteReplacementRule(id: UUID) {
        replacementRules.removeAll { $0.id == id }
    }

    public func moveReplacementRules(from source: IndexSet, to destination: Int) {
        _replacementRules.moveElements(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(_replacementRules)
            defaults.set(data, forKey: "replacementRules")
        } catch {
            logger.error("Failed to encode replacement rules: \(error.localizedDescription)")
        }
        if let shortcut = _replacementShortcutKey {
            do {
                let data = try JSONEncoder().encode(shortcut)
                defaults.set(data, forKey: "replacementShortcut")
            } catch {
                logger.error("Failed to encode replacementShortcut: \(error.localizedDescription)")
            }
        } else {
            defaults.set(Data(), forKey: "replacementShortcut")
        }
        defaults.set(_isAutoReplacementEnabled, forKey: "isAutoReplacementEnabled")
    }
}
