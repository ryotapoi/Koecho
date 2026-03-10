import Foundation
import Observation

@MainActor @Observable
public final class VolumeDuckingSettings {
    private let defaults: UserDefaults

    private var _isVolumeDuckingEnabled: Bool
    public var isVolumeDuckingEnabled: Bool {
        get { _isVolumeDuckingEnabled }
        set {
            _isVolumeDuckingEnabled = newValue
            save()
        }
    }

    private var _volumeDuckingLevel: Float
    public var volumeDuckingLevel: Float {
        get { _volumeDuckingLevel }
        set {
            _volumeDuckingLevel = max(0, min(1, newValue))
            save()
        }
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults

        _isVolumeDuckingEnabled = defaults.object(forKey: "isVolumeDuckingEnabled") as? Bool ?? false
        _volumeDuckingLevel = max(0, min(1, defaults.object(forKey: "volumeDuckingLevel") as? Float ?? 0.05))

        save()
    }

    private func save() {
        defaults.set(_isVolumeDuckingEnabled, forKey: "isVolumeDuckingEnabled")
        defaults.set(_volumeDuckingLevel, forKey: "volumeDuckingLevel")
    }
}
