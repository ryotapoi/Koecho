import Foundation
import SwiftUI
import os

@MainActor @Observable
final class Settings {
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "Settings")

    var pasteDelay: TimeInterval {
        didSet { save() }
    }

    var scriptTimeout: TimeInterval {
        didSet { save() }
    }

    var scripts: [Script] {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let value = defaults.object(forKey: "pasteDelay") as? TimeInterval {
            pasteDelay = value
        } else {
            pasteDelay = 2.0
        }

        if let value = defaults.object(forKey: "scriptTimeout") as? TimeInterval {
            scriptTimeout = value
        } else {
            scriptTimeout = 30.0
        }

        if let data = defaults.data(forKey: "scripts") {
            do {
                scripts = try JSONDecoder().decode([Script].self, from: data)
            } catch {
                logger.warning("Failed to decode scripts, using defaults: \(error.localizedDescription)")
                scripts = []
            }
        } else {
            scripts = []
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
        scripts.removeAll { $0.id == id }
    }

    func moveScripts(from source: IndexSet, to destination: Int) {
        scripts.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        defaults.set(pasteDelay, forKey: "pasteDelay")
        defaults.set(scriptTimeout, forKey: "scriptTimeout")
        do {
            let data = try JSONEncoder().encode(scripts)
            defaults.set(data, forKey: "scripts")
        } catch {
            logger.error("Failed to encode scripts: \(error.localizedDescription)")
        }
    }
}
