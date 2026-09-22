import AppKit
import Foundation
import KoechoCore
import Observation
import os

@MainActor @Observable
public final class HistoryStore {
  // This existing user data location requires migration if it ever changes.
  private static let historyDirectoryName = "com.ryotapoi.koecho"

  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "HistoryStore")
  private let fileURL: URL
  public private(set) var entries: [HistoryEntry] = []
  public private(set) var isUnavailable = false

  public init(directoryURL: URL? = nil) {
    let directory =
      directoryURL
      ?? FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first!.appendingPathComponent(Self.historyDirectoryName)
    self.fileURL = directory.appendingPathComponent("history.json")
    load()
  }

  public func add(text: String, settings: HistorySettings) {
    guard settings.isHistoryEnabled, !isUnavailable else { return }
    let entry = HistoryEntry(text: text)
    entries.insert(entry, at: 0)
    purge(maxCount: settings.historyMaxCount, retentionDays: settings.historyRetentionDays)
  }

  public func clear() {
    guard !isUnavailable else { return }
    entries.removeAll()
    save()
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
