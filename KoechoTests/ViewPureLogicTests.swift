import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
struct ViewPureLogicTests {
  @Test func languageMenuRequiresMultipleAvailableLanguages() {
    let languages = InputPanelLanguages()
    #expect(!languages.hasMultipleLanguages)
    languages.locales = [
      LocaleItem(
        identifier: "ja_JP", displayName: "Japanese", normalizedKey: "ja--JP", isReserved: true)
    ]
    #expect(!languages.hasMultipleLanguages)
    languages.locales.append(
      LocaleItem(
        identifier: "en_US", displayName: "English", normalizedKey: "en--US", isReserved: true)
    )
    #expect(languages.hasMultipleLanguages)
  }

  @Test func languageCodesFitFiveCharactersAndPreserveRegionalDistinctions() {
    #expect(InputPanelLanguages.displayCode(for: "ja_JP") == "ja-JP")
    #expect(InputPanelLanguages.displayCode(for: "en-US") == "en-US")
    #expect(InputPanelLanguages.displayCode(for: "en_GB") == "en-GB")
    #expect(InputPanelLanguages.displayCode(for: "yue_CN") == "yueCN")
    #expect(InputPanelLanguages.displayCode(for: "zh_CN") == "zh-CN")
  }

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

  @Test func loadFailureDescriptionsAreEmptyWhenNothingFailed() {
    let descriptions = KoechoApp.loadFailureDescriptions(
      settingsFailures: [],
      historyIsUnavailable: false
    )

    #expect(descriptions.isEmpty)
  }

  @Test func loadFailureDescriptionsIncludeHistoryWhenOnlyHistoryFailed() {
    let descriptions = KoechoApp.loadFailureDescriptions(
      settingsFailures: [],
      historyIsUnavailable: true
    )

    #expect(descriptions == [
      "History could not be loaded. It is protected, and new entries are not being recorded. Reset it from the History settings page to resume recording."
    ])
  }

  @Test func loadFailureDescriptionsCombineSettingsAndHistoryFailures() {
    let descriptions = KoechoApp.loadFailureDescriptions(
      settingsFailures: [.scripts],
      historyIsUnavailable: true
    )

    #expect(descriptions == [
      "Scripts",
      "History could not be loaded. It is protected, and new entries are not being recorded. Reset it from the History settings page to resume recording.",
    ])
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
