import Foundation
import os

@MainActor @Observable
final class HistoryStore {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "HistoryStore")
    private let fileURL: URL
    private(set) var entries: [HistoryEntry] = []

    init(directoryURL: URL? = nil) {
        let directory = directoryURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("com.ryotapoi.koecho")
        self.fileURL = directory.appendingPathComponent("history.json")
        load()
    }

    func add(text: String, settings: Settings) {
        guard settings.isHistoryEnabled else { return }
        let entry = HistoryEntry(text: text)
        entries.insert(entry, at: 0)
        purge(maxCount: settings.historyMaxCount, retentionDays: settings.historyRetentionDays)
    }

    func clear() {
        entries.removeAll()
        save()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func purge(maxCount: Int, retentionDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
        entries.removeAll { $0.timestamp < cutoff }
        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            logger.warning("Failed to decode history, using empty: \(error.localizedDescription)")
            entries = []
        }
    }

    private func save() {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }
}
