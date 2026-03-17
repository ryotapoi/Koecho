import Foundation
import Observation
import os

@MainActor @Observable
public final class ScriptSettings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ScriptSettings")

    private var _scripts: [Script]
    public var scripts: [Script] {
        get { _scripts }
        set { _scripts = newValue; save() }
    }

    private var _autoRunScriptId: UUID?
    public var autoRunScriptId: UUID? {
        get { _autoRunScriptId }
        set {
            _autoRunScriptId = newValue
            save()
        }
    }

    private var _autoRunShortcutKey: ShortcutKey?
    public var autoRunShortcutKey: ShortcutKey? {
        get { _autoRunShortcutKey }
        set {
            _autoRunShortcutKey = newValue
            save()
        }
    }

    private var _scriptTimeout: TimeInterval
    public var scriptTimeout: TimeInterval {
        get { _scriptTimeout }
        set {
            _scriptTimeout = max(1, newValue)
            save()
        }
    }

    public var eligibleAutoRunScripts: [Script] {
        scripts.filter { !$0.requiresPrompt }
    }

    public var autoRunScript: Script? {
        guard let id = autoRunScriptId else { return nil }
        return eligibleAutoRunScripts.first { $0.id == id }
    }

    public init(defaults: UserDefaults) {
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

    public func addScript(_ script: Script) {
        scripts.append(script)
    }

    public func updateScript(_ script: Script) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
    }

    public func deleteScript(id: UUID) {
        _scripts.removeAll { $0.id == id }
        if _autoRunScriptId == id {
            _autoRunScriptId = nil
        }
        save()
    }

    public func moveScripts(from source: IndexSet, to destination: Int) {
        _scripts.moveElements(fromOffsets: source, toOffset: destination)
        save()
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
            do {
                let data = try JSONEncoder().encode(shortcut)
                defaults.set(data, forKey: "autoRunShortcut")
            } catch {
                logger.error("Failed to encode autoRunShortcut: \(error.localizedDescription)")
            }
        } else {
            defaults.set(Data(), forKey: "autoRunShortcut")
        }
    }
}
