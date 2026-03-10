import Foundation
import Observation

@MainActor @Observable
public final class HistorySettings {
    private let defaults: UserDefaults

    private var _isHistoryEnabled: Bool
    public var isHistoryEnabled: Bool {
        get { _isHistoryEnabled }
        set {
            _isHistoryEnabled = newValue
            save()
        }
    }

    private var _historyMaxCount: Int
    public var historyMaxCount: Int {
        get { _historyMaxCount }
        set {
            _historyMaxCount = max(1, newValue)
            save()
        }
    }

    private var _historyRetentionDays: Int
    public var historyRetentionDays: Int {
        get { _historyRetentionDays }
        set {
            _historyRetentionDays = max(1, newValue)
            save()
        }
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults

        _isHistoryEnabled = defaults.object(forKey: "isHistoryEnabled") as? Bool ?? true
        _historyMaxCount = max(1, defaults.object(forKey: "historyMaxCount") as? Int ?? 500)
        _historyRetentionDays = max(1, defaults.object(forKey: "historyRetentionDays") as? Int ?? 30)

        save()
    }

    private func save() {
        defaults.set(_isHistoryEnabled, forKey: "isHistoryEnabled")
        defaults.set(_historyMaxCount, forKey: "historyMaxCount")
        defaults.set(_historyRetentionDays, forKey: "historyRetentionDays")
    }
}
