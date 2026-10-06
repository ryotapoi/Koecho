import AppKit
import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
@Suite(.serialized)
struct HistoryStoreTests {
  private func makeTempDirectory() -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("koecho-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private func makeSettings(
    isHistoryEnabled: Bool = true,
    historyMaxCount: Int = 500,
    historyRetentionDays: Int = 30
  ) -> HistorySettings {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = HistorySettings(defaults: defaults)
    settings.isHistoryEnabled = isHistoryEnabled
    settings.historyMaxCount = historyMaxCount
    settings.historyRetentionDays = historyRetentionDays
    return settings
  }

  @Test func migrationHandlesActualFilesystemCaseSemantics() throws {
    // CHANGE-VERIFY: Allow the same filesystem contract test on a dedicated case-sensitive image.
    let base = ProcessInfo.processInfo.environment["KOECHO_HISTORY_TEST_ROOT"]
      .map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory
    let root = base.appendingPathComponent("koecho-case-fixture-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("com.ryotapoi.koecho")
    let destination = root.appendingPathComponent("com.ryotapoi.Koecho")
    HistoryStore(directoryURL: legacy).add(text: "preserved", settings: makeSettings())
    let oldFile = legacy.appendingPathComponent("history.json")
    let before = try Data(contentsOf: oldFile)
    let aliasedBeforeMigration = FileManager.default.fileExists(
      atPath: destination.appendingPathComponent("history.json").path
    )
    let store = HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy)
    #expect(!store.isUnavailable)
    #expect(store.entries.map(\.text) == ["preserved"])
    #expect(try Data(contentsOf: destination.appendingPathComponent("history.json")) == before)
    #expect(FileManager.default.fileExists(atPath: oldFile.path) == aliasedBeforeMigration)
    #expect(HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy).entries.map(\.text) == ["preserved"])
  }

  @Test func legacyMigrationPersistsAndDoesNotRestoreClearedHistory() throws {
    let root = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("legacy")
    let destination = root.appendingPathComponent("destination")
    let settings = makeSettings()
    HistoryStore(directoryURL: legacy).add(text: "legacy", settings: settings)
    let unrelated = legacy.appendingPathComponent("unrelated.txt")
    try Data("keep".utf8).write(to: unrelated)
    let store = HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy)
    #expect(!store.isUnavailable)
    #expect(store.entries.map(\.text) == ["legacy"])
    #expect(HistoryStore(directoryURL: destination).entries.map(\.text) == ["legacy"])
    #expect(try Data(contentsOf: unrelated) == Data("keep".utf8))
    #expect(store.clear())
    // A leftover old file must never override the authoritative destination.
    HistoryStore(directoryURL: legacy).add(text: "stale", settings: settings)
    let oldData = try Data(contentsOf: legacy.appendingPathComponent("history.json"))
    let reloaded = HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy)
    #expect(!reloaded.isUnavailable)
    #expect(reloaded.entries.isEmpty)
    #expect(try Data(contentsOf: legacy.appendingPathComponent("history.json")) == oldData)
  }

  @Test func corruptLegacyRemainsProtectedUntilExplicitInitialization() throws {
    let root = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("legacy")
    let destination = root.appendingPathComponent("destination")
    try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    let corrupt = Data("invalid JSON".utf8)
    try corrupt.write(to: legacy.appendingPathComponent("history.json"))
    let store = HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy)
    #expect(store.isUnavailable)
    store.purge(maxCount: 1, retentionDays: 1)
    store.add(text: "blocked", settings: makeSettings())
    #expect(!store.clear())
    #expect(try Data(contentsOf: destination.appendingPathComponent("history.json")) == corrupt)
    #expect(store.initializeUnavailableHistory())
    #expect(!HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy).isUnavailable)
  }

  @Test func migrationFailureProtectsLegacyAndDoesNotCreateEmptyDestination() throws {
    let root = makeTempDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("legacy")
    HistoryStore(directoryURL: legacy).add(text: "keep", settings: makeSettings())
    let oldFile = legacy.appendingPathComponent("history.json")
    let oldData = try Data(contentsOf: oldFile)
    let blocker = root.appendingPathComponent("blocked")
    try Data("file instead of directory".utf8).write(to: blocker)
    let destination = blocker.appendingPathComponent("destination")
    let store = HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy)
    #expect(store.isUnavailable)
    store.purge(maxCount: 0, retentionDays: 0)
    store.add(text: "blocked", settings: makeSettings())
    store.deleteEntry(id: UUID())
    #expect(!store.clear())
    #expect(!store.initializeUnavailableHistory())
    #expect(try Data(contentsOf: oldFile) == oldData)
    // Removing the fixture obstruction allows the explicit reset; the old file
    // then remains ignored on subsequent launches.
    try FileManager.default.removeItem(at: blocker)
    #expect(store.initializeUnavailableHistory())
    #expect(HistoryStore(directoryURL: destination, legacyDirectoryURL: legacy).entries.isEmpty)
    #expect(try Data(contentsOf: oldFile) == oldData)
  }

  @Test func addInsertsEntry() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings()
    #expect(!store.isUnavailable)
    store.add(text: "hello", settings: settings)
    #expect(store.entries.count == 1)
    #expect(store.entries[0].text == "hello")
  }

  @Test func addWhenDisabledIsNoop() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings(isHistoryEnabled: false)
    store.add(text: "hello", settings: settings)
    #expect(store.entries.isEmpty)
  }

  @Test func retentionDaysPurge() {
    let dir = makeTempDirectory()
    let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
    let oldEntry = HistoryEntry(text: "old", timestamp: oldDate)
    let recentEntry = HistoryEntry(text: "recent", timestamp: Date())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try! encoder.encode([recentEntry, oldEntry])
    let fileURL = dir.appendingPathComponent("history.json")
    try! data.write(to: fileURL, options: .atomic)
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings(historyRetentionDays: 30)
    store.purge(maxCount: settings.historyMaxCount, retentionDays: settings.historyRetentionDays)
    #expect(store.entries.count == 1)
    #expect(store.entries[0].text == "recent")
  }

  @Test func clear() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings()
    store.add(text: "a", settings: settings)
    store.add(text: "b", settings: settings)
    #expect(store.clear())
    #expect(store.entries.isEmpty)
    let store2 = HistoryStore(directoryURL: dir)
    #expect(store2.entries.isEmpty)
  }

  @Test func failedClearPreservesReadableHistoryAndCanBeRetried() throws {
    let dir = makeTempDirectory()
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
      try? FileManager.default.removeItem(at: dir)
    }
    let fileURL = dir.appendingPathComponent("history.json")
    let settings = makeSettings()
    let initialStore = HistoryStore(directoryURL: dir)
    initialStore.add(text: "retained history", settings: settings)
    let store = HistoryStore(directoryURL: dir)
    let loadedEntries = store.entries
    let original = try Data(contentsOf: fileURL)

    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)
    #expect(!store.clear())
    #expect(store.entries == loadedEntries)
    #expect(!store.isUnavailable)
    #expect(try Data(contentsOf: fileURL) == original)
    let reloaded = HistoryStore(directoryURL: dir)
    #expect(reloaded.entries == loadedEntries)
    #expect(!reloaded.isUnavailable)

    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    #expect(store.clear())
    #expect(store.entries.isEmpty)
    let cleared = HistoryStore(directoryURL: dir)
    #expect(cleared.entries.isEmpty)
    #expect(!cleared.isUnavailable)
  }

  @Test func deleteEntry() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings()
    store.add(text: "keep", settings: settings)
    store.add(text: "delete", settings: settings)
    let deleteID = store.entries[0].id
    store.deleteEntry(id: deleteID)
    #expect(store.entries.count == 1)
    #expect(store.entries[0].text == "keep")
  }

  @Test func corruptedJSONProtectsOriginalFileFromAllMutations() {
    let dir = makeTempDirectory()
    let fileURL = dir.appendingPathComponent("history.json")
    let original = Data("invalid json".utf8)
    try! original.write(to: fileURL, options: .atomic)
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings()

    #expect(store.entries.isEmpty)
    #expect(store.isUnavailable)

    store.purge(maxCount: settings.historyMaxCount, retentionDays: settings.historyRetentionDays)
    store.add(text: "new entry", settings: settings)
    #expect(!store.clear())
    store.deleteEntry(id: UUID())

    #expect(store.entries.isEmpty)
    #expect(try! Data(contentsOf: fileURL) == original)
  }

  @Test func initializingUnavailableHistoryRestoresRecording() {
    let dir = makeTempDirectory()
    let fileURL = dir.appendingPathComponent("history.json")
    try! Data("invalid json".utf8).write(to: fileURL, options: .atomic)
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings()

    #expect(store.isUnavailable)
    #expect(store.initializeUnavailableHistory())
    #expect(!store.isUnavailable)
    #expect(store.entries.isEmpty)

    store.add(text: "recovered", settings: settings)
    let reloaded = HistoryStore(directoryURL: dir)
    #expect(!reloaded.isUnavailable)
    #expect(reloaded.entries.map(\.text) == ["recovered"])
  }

  @Test func failedInitializationKeepsHistoryUnavailable() {
    let dir = makeTempDirectory()
    let fileURL = dir.appendingPathComponent("history.json")
    try! FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
    let store = HistoryStore(directoryURL: dir)

    #expect(store.isUnavailable)
    #expect(!store.initializeUnavailableHistory())
    #expect(store.isUnavailable)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
  }

  @Test func emptyDirectoryLoadsEmpty() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    #expect(store.entries.isEmpty)
    #expect(!store.isUnavailable)
  }

  private func makeTestPasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("com.ryotapoi.koecho.test.\(UUID().uuidString)"))
  }

  @Test func copyToClipboardSetsText() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let entry = HistoryEntry(text: "clipboard test")
    let pb = makeTestPasteboard()
    store.copyToClipboard(entry: entry, using: pb)
    #expect(pb.string(forType: .string) == "clipboard test")
  }

  @Test func copyLatestToClipboardCopiesFirstEntry() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let settings = makeSettings()
    let pb = makeTestPasteboard()
    store.add(text: "first", settings: settings)
    store.add(text: "second", settings: settings)
    let result = store.copyLatestToClipboard(using: pb)
    #expect(result == true)
    #expect(pb.string(forType: .string) == "second")
  }

  @Test func copyLatestToClipboardReturnsFalseWhenEmpty() {
    let dir = makeTempDirectory()
    let store = HistoryStore(directoryURL: dir)
    let pb = makeTestPasteboard()
    let result = store.copyLatestToClipboard(using: pb)
    #expect(result == false)
  }

  @Test func purgePersistsResult() {
    let dir = makeTempDirectory()
    let settings = makeSettings(historyMaxCount: 500)
    let store = HistoryStore(directoryURL: dir)
    store.add(text: "a", settings: settings)
    store.add(text: "b", settings: settings)
    store.add(text: "c", settings: settings)
    #expect(store.entries.count == 3)
    store.purge(maxCount: 2, retentionDays: 30)
    #expect(store.entries.count == 2)
    let reloaded = HistoryStore(directoryURL: dir)
    #expect(reloaded.entries.count == 2)
    #expect(reloaded.entries[0].text == "c")
    #expect(reloaded.entries[1].text == "b")
  }

  @Test func maxCountKeepsNewestOnAdd() {
    let dir = makeTempDirectory()
    let settings = makeSettings(historyMaxCount: 2)
    let store = HistoryStore(directoryURL: dir)
    store.add(text: "1", settings: settings)
    store.add(text: "2", settings: settings)
    store.add(text: "3", settings: settings)
    #expect(store.entries.count == 2)
    #expect(store.entries[0].text == "3")
    #expect(store.entries[1].text == "2")
    let reloaded = HistoryStore(directoryURL: dir)
    #expect(reloaded.entries.count == 2)
  }
}
