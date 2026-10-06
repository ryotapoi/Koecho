import AppKit
import Foundation
import KoechoCore
import Observation
import os

@MainActor @Observable
public final class HistoryStore {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "HistoryStore")
  private let fileURL: URL
  public private(set) var entries: [HistoryEntry] = []
  public private(set) var isUnavailable = false

  public init(directoryURL: URL, legacyDirectoryURL: URL? = nil) {
    self.fileURL = directoryURL.appendingPathComponent("history.json")
    do {
      if let legacyDirectoryURL {
        try migrateLegacyHistory(from: legacyDirectoryURL.appendingPathComponent("history.json"))
      }
      load()
    } catch {
      logger.warning("Failed to migrate history: \(error.localizedDescription)")
      isUnavailable = true
    }
  }

  private func migrateLegacyHistory(from legacyFileURL: URL) throws {
    // A reachable destination is authoritative, including on case-insensitive volumes
    // where the old and new spellings already refer to the same file.
    guard try !Self.historyFileExists(at: fileURL) else { return }
    guard try Self.historyFileExists(at: legacyFileURL) else { return }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try FileManager.default.moveItem(at: legacyFileURL, to: fileURL)
  }

  private static func historyFileExists(at url: URL) throws -> Bool {
    do {
      return try url.checkResourceIsReachable()
    } catch let error as CocoaError
      where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
    {
      return false
    }
  }

  public func add(text: String, settings: HistorySettings) {
    guard settings.isHistoryEnabled, !isUnavailable else { return }
    let entry = HistoryEntry(text: text)
    entries.insert(entry, at: 0)
    purge(maxCount: settings.historyMaxCount, retentionDays: settings.historyRetentionDays)
  }

  @discardableResult
  public func clear() -> Bool {
    guard !isUnavailable, save(entries: []) else { return false }
    entries.removeAll()
    return true
  }

  public func deleteEntry(id: UUID) {
    guard !isUnavailable else { return }
    entries.removeAll { $0.id == id }
    save()
  }

  @discardableResult
  public func initializeUnavailableHistory() -> Bool {
    guard isUnavailable else { return true }
    guard save(entries: []) else { return false }
    entries = []
    isUnavailable = false
    return true
  }

  public func copyToClipboard(entry: HistoryEntry, using pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    pasteboard.setString(entry.text, forType: .string)
  }

  @discardableResult
  public func copyLatestToClipboard(using pasteboard: NSPasteboard = .general) -> Bool {
    guard let entry = entries.first else { return false }
    copyToClipboard(entry: entry, using: pasteboard)
    return true
  }

  public func purge(maxCount: Int, retentionDays: Int) {
    guard !isUnavailable else { return }
    let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
    entries.removeAll { $0.timestamp < cutoff }
    if entries.count > maxCount {
      entries = Array(entries.prefix(maxCount))
    }
    save()
  }

  private func load() {
    do {
      let data = try Data(contentsOf: fileURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      entries = try decoder.decode([HistoryEntry].self, from: data)
    } catch {
      if let cocoaError = error as? CocoaError,
        cocoaError.code == .fileNoSuchFile || cocoaError.code == .fileReadNoSuchFile
      {
        entries = []
        return
      }
      logger.warning("Failed to load history: \(error.localizedDescription)")
      entries = []
      isUnavailable = true
    }
  }

  private func save() {
    _ = save(entries: entries)
  }

  @discardableResult
  private func save(entries: [HistoryEntry]) -> Bool {
    let directory = fileURL.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(entries)
      try data.write(to: fileURL, options: .atomic)
      return true
    } catch {
      logger.error("Failed to save history: \(error.localizedDescription)")
      return false
    }
  }
}
