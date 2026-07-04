import Foundation
import KoechoCore
import Testing

@testable import Koecho

@MainActor
struct ViewPureLogicTests {
  @Test func duplicatePatternsCountsEachPatternOncePerRule() {
    let rules = [
      ReplacementRule(patterns: ["alpha", "alpha", ""], replacement: "one"),
      ReplacementRule(patterns: ["beta"], replacement: "two"),
      ReplacementRule(patterns: ["alpha", "gamma"], replacement: "three"),
      ReplacementRule(pattern: "beta", replacement: "four", usesRegularExpression: true),
      ReplacementRule(pattern: "", replacement: "empty", usesRegularExpression: true),
    ]

    let duplicates = ReplacementRuleManagementViewLogic.duplicatePatterns(in: rules)

    #expect(duplicates == ["alpha", "beta"])
  }

  @Test func duplicatePatternsIgnoresEmptyPatterns() {
    let rules = [
      ReplacementRule(patterns: ["", ""], replacement: "one"),
      ReplacementRule(pattern: "", replacement: "two", usesRegularExpression: true),
    ]

    let duplicates = ReplacementRuleManagementViewLogic.duplicatePatterns(in: rules)

    #expect(duplicates.isEmpty)
  }

  @Test func filteredEntriesReturnsAllEntriesForEmptySearchText() {
    let entries = makeHistoryEntries()

    let filtered = HistoryViewLogic.filteredEntries(searchText: "", entries: entries)

    #expect(filtered == entries)
  }

  @Test func filteredEntriesUsesLocalizedStandardContains() {
    let entries = makeHistoryEntries()

    let filtered = HistoryViewLogic.filteredEntries(searchText: "meeting", entries: entries)

    #expect(filtered == [entries[1]])
  }

  @Test func levelColorUsesExpectedThresholds() {
    #expect(InputLevelMeterLogic.levelColor(for: 0.0) == .green)
    #expect(InputLevelMeterLogic.levelColor(for: 0.7) == .green)
    #expect(InputLevelMeterLogic.levelColor(for: 0.7001) == .yellow)
    #expect(InputLevelMeterLogic.levelColor(for: 0.9) == .yellow)
    #expect(InputLevelMeterLogic.levelColor(for: 0.9001) == .red)
  }

  private func makeHistoryEntries() -> [HistoryEntry] {
    [
      HistoryEntry(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        text: "Draft release notes",
        timestamp: Date(timeIntervalSince1970: 1)
      ),
      HistoryEntry(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        text: "Meeting transcript",
        timestamp: Date(timeIntervalSince1970: 2)
      ),
      HistoryEntry(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        text: "買い物メモ",
        timestamp: Date(timeIntervalSince1970: 3)
      ),
    ]
  }
}
