import Foundation
import SwiftUI
import os

@MainActor @Observable
final class ScriptSettings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "ScriptSettings")

    private var _scripts: [Script]
    var scripts: [Script] {
        get { _scripts }
        set { _scripts = newValue; save() }
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

    private var _scriptTimeout: TimeInterval
    var scriptTimeout: TimeInterval {
        get { _scriptTimeout }
        set {
            _scriptTimeout = max(1, newValue)
            save()
        }
    }

    var autoRunScript: Script? {
        guard let id = autoRunScriptId else { return nil }
        return scripts.first { $0.id == id && !$0.requiresPrompt }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults

        _scriptTimeout = max(1, defaults.object(forKey: "scriptTimeout") as? TimeInterval ?? 30.0)

        if let data = defaults.data(forKey: "scripts") {
            do {
                _scripts = try JSONDecoder().decode([Script].self, from: data)
            } catch {
                logger.warning("Failed to decode scripts, using defaults: \(error.localizedDescription)")
                _scripts = []
            }
        } else {
            _scripts = []
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
        _scripts.removeAll { $0.id == id }
        if _autoRunScriptId == id {
            _autoRunScriptId = nil
        }
        save()
    }

    func moveScripts(from source: IndexSet, to destination: Int) {
        scripts.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        defaults.set(_scriptTimeout, forKey: "scriptTimeout")
        do {
            let data = try JSONEncoder().encode(_scripts)
            defaults.set(data, forKey: "scripts")
        } catch {
            logger.error("Failed to encode scripts: \(error.localizedDescription)")
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
    }
}
