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

    @Test func addInsertsEntry() {
        let dir = makeTempDirectory()
        let store = HistoryStore(directoryURL: dir)
        let settings = makeSettings()
        store.add(text: "hello", settings: settings)
        #expect(store.entries.count == 1)
        #expect(store.entries[0].text == "hello")
    }

    @Test func newestFirst() {
        let dir = makeTempDirectory()
        let store = HistoryStore(directoryURL: dir)
        let settings = makeSettings()
        store.add(text: "first", settings: settings)
        store.add(text: "second", settings: settings)
        #expect(store.entries.count == 2)
        #expect(store.entries[0].text == "second")
        #expect(store.entries[1].text == "first")
    }

    @Test func addWhenDisabledIsNoop() {
        let dir = makeTempDirectory()
        let store = HistoryStore(directoryURL: dir)
        let settings = makeSettings(isHistoryEnabled: false)
        store.add(text: "hello", settings: settings)
        #expect(store.entries.isEmpty)
    }

    @Test func maxCountLimit() {
        let dir = makeTempDirectory()
        let store = HistoryStore(directoryURL: dir)
        let settings = makeSettings(historyMaxCount: 3)
        store.add(text: "1", settings: settings)
        store.add(text: "2", settings: settings)
        store.add(text: "3", settings: settings)
        store.add(text: "4", settings: settings)
        #expect(store.entries.count == 3)
        #expect(store.entries[0].text == "4")
        #expect(store.entries[1].text == "3")
        #expect(store.entries[2].text == "2")
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

    @Test func persistAndReload() {
        let dir = makeTempDirectory()
        let settings = makeSettings()
        let store1 = HistoryStore(directoryURL: dir)
        store1.add(text: "persisted", settings: settings)
        let store2 = HistoryStore(directoryURL: dir)
        #expect(store2.entries.count == 1)
        #expect(store2.entries[0].text == "persisted")
    }

    @Test func clear() {
        let dir = makeTempDirectory()
        let store = HistoryStore(directoryURL: dir)
        let settings = makeSettings()
        store.add(text: "a", settings: settings)
        store.add(text: "b", settings: settings)
        store.clear()
        #expect(store.entries.isEmpty)
        let store2 = HistoryStore(directoryURL: dir)
        #expect(store2.entries.isEmpty)
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

    @Test func corruptedJSONFallsBackToEmpty() {
        let dir = makeTempDirectory()
        let fileURL = dir.appendingPathComponent("history.json")
        try! Data("invalid json".utf8).write(to: fileURL, options: .atomic)
        let store = HistoryStore(directoryURL: dir)
        #expect(store.entries.isEmpty)
    }

    @Test func emptyDirectoryLoadsEmpty() {
        let dir = makeTempDirectory()
        let store = HistoryStore(directoryURL: dir)
        #expect(store.entries.isEmpty)
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
