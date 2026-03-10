import Foundation
import os

@MainActor @Observable
final class HotkeySettings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "HotkeySettings")

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

    init(defaults: UserDefaults) {
        self.defaults = defaults

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

    private func save() {
        do {
            let data = try JSONEncoder().encode(_hotkeyConfig)
            defaults.set(data, forKey: "hotkeyConfig")
        } catch {
            logger.error("Failed to encode hotkey config: \(error.localizedDescription)")
        }
    }
}
