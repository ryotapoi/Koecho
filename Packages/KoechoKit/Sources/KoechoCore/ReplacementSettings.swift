import Foundation
import Observation
import os

@MainActor @Observable
public final class ReplacementSettings {
  static let defaultReplacementShortcutKey = ShortcutKey(modifiers: [.control], character: "r")

  private let defaults: UserDefaults
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ReplacementSettings")

  public private(set) var loadFailures: Set<SettingsLoadFailure> = []
  public private(set) var isReplacementRulesProtected = false

  private var _replacementRules: [ReplacementRule]
  public var replacementRules: [ReplacementRule] {
    get { _replacementRules }
    set {
      guard !isReplacementRulesProtected else { return }
      _replacementRules = newValue
      save()
    }
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
    _replacementRules = []
    _replacementShortcutKey = Self.defaultReplacementShortcutKey
    _isAutoReplacementEnabled = false

    if let storedRules = defaults.object(forKey: "replacementRules") {
      if let data = storedRules as? Data {
        do {
          _replacementRules = try JSONDecoder().decode([ReplacementRule].self, from: data)
        } catch {
          logger.warning("Failed to decode replacement rules: \(error.localizedDescription)")
          loadFailures.insert(.replacementRules)
          isReplacementRulesProtected = true
          _replacementRules = []
        }
      } else {
        loadFailures.insert(.replacementRules)
        isReplacementRulesProtected = true
        _replacementRules = []
      }
    } else {
      _replacementRules = []
    }

    if let storedShortcut = defaults.object(forKey: "replacementShortcut") {
      if let data = storedShortcut as? Data {
        do {
          _replacementShortcutKey = try ShortcutKey.decodeOptional(from: data)
        } catch {
          logger.warning("Failed to decode replacementShortcut, using default")
          loadFailures.insert(.replacementShortcut)
          _replacementShortcutKey = Self.defaultReplacementShortcutKey
        }
      } else {
        loadFailures.insert(.replacementShortcut)
        _replacementShortcutKey = Self.defaultReplacementShortcutKey
      }
    } else {
      _replacementShortcutKey = Self.defaultReplacementShortcutKey
    }

    if let enabled = defaults.object(forKey: "isAutoReplacementEnabled") {
      if let enabled = enabled as? Bool {
        _isAutoReplacementEnabled = enabled
      } else {
        loadFailures.insert(.isAutoReplacementEnabled)
        _isAutoReplacementEnabled = false
      }
    } else {
      _isAutoReplacementEnabled = false
    }

    save()
  }

  public func addReplacementRule(_ rule: ReplacementRule) {
    guard !isReplacementRulesProtected else { return }
    replacementRules.append(rule)
  }

  public func updateReplacementRule(_ rule: ReplacementRule) {
    guard !isReplacementRulesProtected else { return }
    guard let index = replacementRules.firstIndex(where: { $0.id == rule.id }) else { return }
    replacementRules[index] = rule
  }

  public func deleteReplacementRule(id: UUID) {
    guard !isReplacementRulesProtected else { return }
    replacementRules.removeAll { $0.id == id }
  }

  public func moveReplacementRules(from source: IndexSet, to destination: Int) {
    guard !isReplacementRulesProtected else { return }
    _replacementRules.moveElements(fromOffsets: source, toOffset: destination)
    save()
  }

  public func resetReplacementRules() {
    _replacementRules = []
    isReplacementRulesProtected = false
    save()
  }

  private func save() {
    if !isReplacementRulesProtected {
      do {
        let data = try JSONEncoder().encode(_replacementRules)
        defaults.set(data, forKey: "replacementRules")
      } catch {
        logger.error("Failed to encode replacement rules: \(error.localizedDescription)")
      }
    }
    do {
      let data = try ShortcutKey.encodeOptional(_replacementShortcutKey)
      defaults.set(data, forKey: "replacementShortcut")
    } catch {
      logger.error("Failed to encode replacementShortcut: \(error.localizedDescription)")
    }
    defaults.set(_isAutoReplacementEnabled, forKey: "isAutoReplacementEnabled")
  }
}
