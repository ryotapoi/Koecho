import Foundation

@MainActor @Observable
final class PasteSettings {
    private let defaults: UserDefaults

    private var _pasteDelay: TimeInterval
    var pasteDelay: TimeInterval {
        get { _pasteDelay }
        set {
            _pasteDelay = max(0, newValue)
            save()
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults

        _pasteDelay = max(0, defaults.object(forKey: "pasteDelay") as? TimeInterval ?? 2.0)

        save()
    }

    private func save() {
        defaults.set(_pasteDelay, forKey: "pasteDelay")
    }
}
