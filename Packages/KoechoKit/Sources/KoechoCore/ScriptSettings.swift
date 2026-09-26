import Foundation
import Observation
import os

@MainActor @Observable
public final class ScriptSettings {
  private static let builtinScriptsRegisteredKey = "builtinScriptsRegistered"

  private let defaults: UserDefaults
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ScriptSettings")

  public private(set) var loadFailures: Set<SettingsLoadFailure> = []
  public private(set) var isScriptsProtected = false

  private var _scripts: [Script]
  public var scripts: [Script] {
    get { _scripts }
    set {
      guard !isScriptsProtected else { return }
      _scripts = Self.deduplicatingBuiltinScripts(newValue)
      save()
    }
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
    scripts.filter { $0.kind == .custom && !$0.requiresPrompt }
  }

  public var autoRunScript: Script? {
    guard let id = autoRunScriptId else { return nil }
    return eligibleAutoRunScripts.first { $0.id == id }
  }

  public init(defaults: UserDefaults) {
    self.defaults = defaults
    _scripts = []
    _autoRunScriptId = nil
    _autoRunShortcutKey = nil
    _scriptTimeout = 30.0

    if let timeout = defaults.object(forKey: "scriptTimeout") {
      if let timeout = timeout as? TimeInterval {
        _scriptTimeout = max(1, timeout)
      } else {
        loadFailures.insert(.scriptTimeout)
        _scriptTimeout = 30.0
      }
    } else {
      _scriptTimeout = 30.0
    }

    if let storedScripts = defaults.object(forKey: "scripts") {
      if let data = storedScripts as? Data {
        do {
          _scripts = try JSONDecoder().decode([Script].self, from: data)
        } catch {
          logger.warning("Failed to decode scripts: \(error.localizedDescription)")
          loadFailures.insert(.scripts)
          isScriptsProtected = true
          _scripts = []
        }
      } else {
        loadFailures.insert(.scripts)
        isScriptsProtected = true
        _scripts = []
      }
    } else {
      _scripts = []
    }

    if !isScriptsProtected && !defaults.bool(forKey: Self.builtinScriptsRegisteredKey) {
      _scripts.append(contentsOf: Script.defaultBuiltins)
      defaults.set(true, forKey: Self.builtinScriptsRegisteredKey)
    }
    if !isScriptsProtected {
      _scripts = Self.deduplicatingBuiltinScripts(_scripts)
    }

    if let storedID = defaults.object(forKey: "autoRunScriptId") {
      if let uuidString = storedID as? String, let id = UUID(uuidString: uuidString) {
        _autoRunScriptId = id
      } else {
        loadFailures.insert(.autoRunScriptId)
        _autoRunScriptId = nil
      }
    } else {
      _autoRunScriptId = nil
    }

    if let storedShortcut = defaults.object(forKey: "autoRunShortcut") {
      if let data = storedShortcut as? Data {
        do {
          _autoRunShortcutKey = try ShortcutKey.decodeOptional(from: data)
        } catch {
          logger.warning("Failed to decode autoRunShortcut, using nil")
          loadFailures.insert(.autoRunShortcut)
          _autoRunShortcutKey = nil
        }
      } else {
        loadFailures.insert(.autoRunShortcut)
        _autoRunShortcutKey = nil
      }
    } else {
      _autoRunShortcutKey = nil
    }

    save()
  }

  public func addScript(_ script: Script) {
    guard !isScriptsProtected else { return }
    scripts.append(script)
  }

  public func updateScript(_ script: Script) {
    guard !isScriptsProtected else { return }
    guard let index = _scripts.firstIndex(where: { $0.id == script.id }) else { return }
    var updated = _scripts
    updated[index] = script
    scripts = updated
  }

  public func deleteScript(id: UUID) {
    guard !isScriptsProtected else { return }
    scripts.removeAll { $0.id == id }
    if _autoRunScriptId == id {
      _autoRunScriptId = nil
    }
    save()
  }

  public func moveScripts(from source: IndexSet, to destination: Int) {
    guard !isScriptsProtected else { return }
    var reordered = _scripts
    reordered.moveElements(fromOffsets: source, toOffset: destination)
    scripts = reordered
  }

  public func resetScripts() {
    _scripts = []
    isScriptsProtected = false
    defaults.set(true, forKey: Self.builtinScriptsRegisteredKey)
    save()
  }

  private func save() {
    defaults.set(_scriptTimeout, forKey: "scriptTimeout")
    if !isScriptsProtected {
      do {
        let data = try JSONEncoder().encode(_scripts)
        defaults.set(data, forKey: "scripts")
      } catch {
        logger.error("Failed to encode scripts: \(error.localizedDescription)")
      }
    }
    if let id = _autoRunScriptId {
      defaults.set(id.uuidString, forKey: "autoRunScriptId")
    } else {
      defaults.removeObject(forKey: "autoRunScriptId")
    }
    do {
      let data = try ShortcutKey.encodeOptional(_autoRunShortcutKey)
      defaults.set(data, forKey: "autoRunShortcut")
    } catch {
      logger.error("Failed to encode autoRunShortcut: \(error.localizedDescription)")
    }
  }

  private static func deduplicatingBuiltinScripts(_ scripts: [Script]) -> [Script] {
    var accepted: [Script] = []
    var registeredBuiltins: [BuiltinScript] = []

    for script in scripts {
      guard let builtin = script.builtin else {
        accepted.append(script)
        continue
      }
      guard !registeredBuiltins.contains(builtin) else { continue }
      registeredBuiltins.append(builtin)
      accepted.append(script)
    }

    return accepted
  }

}
