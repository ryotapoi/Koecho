import KoechoCore
import KoechoPlatform
import SwiftUI

struct HistoryView: View {
  var historyStore: HistoryStore
  var historySettings: HistorySettings
  @State private var searchText = ""
  @State private var filteredEntries: [HistoryEntry]
  @State private var copiedEntryID: UUID?
  @State private var resetCopiedTask: Task<Void, Never>?
  @State private var popoverEntryID: UUID?
  @State private var isShowingResetConfirmation = false
  @State private var isShowingResetError = false
  @State private var isShowingClearError = false

  init(historyStore: HistoryStore, historySettings: HistorySettings) {
    self.historyStore = historyStore
    self.historySettings = historySettings
    _filteredEntries = State(
      initialValue: HistoryViewLogic.filteredEntries(
        searchText: "",
        entries: historyStore.entries
      )
    )
  }

  var body: some View {
    VStack(spacing: 8) {
      HistorySettingsGroup(settings: historySettings)
        .layoutPriority(1)

      if historyStore.isUnavailable {
        HistoryUnavailableContent(
          onReset: { isShowingResetConfirmation = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        HistorySearchField(searchText: $searchText)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 20)
        HistoryList(
          entries: filteredEntries,
          copiedEntryID: copiedEntryID,
          popoverEntryID: $popoverEntryID,
          onCopy: copyEntry
        )
        .padding(.horizontal, 20)
      }
    }
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !historyStore.isUnavailable {
        HistoryFooter(entryCount: historyStore.entries.count, onClear: clearHistory)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
      }
    }
    .onAppear(perform: updateFilteredEntries)
    .onChange(of: searchText) {
      updateFilteredEntries()
    }
    .onChange(of: historyStore.entries) {
      updateFilteredEntries()
    }
    .confirmationDialog(
      "Reset History?",
      isPresented: $isShowingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset History", role: .destructive) {
        if !historyStore.initializeUnavailableHistory() {
          isShowingResetError = true
        }
      }
    } message: {
      Text("This permanently replaces the unreadable history with an empty history.")
    }
    .alert("History Could Not Be Reset", isPresented: $isShowingResetError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("The unreadable history is still protected. Check available disk space and try again.")
    }
    .alert("History Could Not Be Cleared", isPresented: $isShowingClearError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Your history has not been cleared. Check available disk space and write permissions, then try again.")
    }
  }

  private func clearHistory() {
    if !historyStore.clear() {
      isShowingClearError = true
    }
  }

  private func copyEntry(_ entry: HistoryEntry) {
    historyStore.copyToClipboard(entry: entry)
    withAnimation {
      copiedEntryID = entry.id
    }
    resetCopiedTask?.cancel()
    resetCopiedTask = Task {
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      withAnimation {
        copiedEntryID = nil
      }
    }
  }

  private func updateFilteredEntries() {
    filteredEntries = HistoryViewLogic.filteredEntries(
      searchText: searchText,
      entries: historyStore.entries
    )
  }
}

private struct HistoryUnavailableContent: View {
  let onReset: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("History Unavailable", systemImage: "exclamationmark.triangle")
    } description: {
      Text("Koecho could not read your history. It is protected and new entries are not being recorded.")
    } actions: {
      Button("Reset History", role: .destructive, action: onReset)
      Text("Resetting replaces the unreadable history with an empty history.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

enum HistoryViewLogic {
  static func filteredEntries(searchText: String, entries: [HistoryEntry]) -> [HistoryEntry] {
    if searchText.isEmpty {
      return entries
    }
    return entries.filter {
      $0.text.localizedStandardContains(searchText)
    }
  }
}

// MARK: - Previews

#Preview("With Entries") {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("preview-history-withEntries")
  try? FileManager.default.removeItem(at: dir)
  let store = HistoryStore(directoryURL: dir)
  let historySettings = HistorySettings(
    defaults: UserDefaults(suiteName: "preview-history-withEntries")!
  )
  store.add(text: "Hello, this is a test transcription.", settings: historySettings)
  store.add(text: "もう一つのテスト入力。日本語のテキストです。", settings: historySettings)
  store.add(
    text:
      "A longer entry that might wrap to multiple lines. This tests the line limit behavior of the history row.",
    settings: historySettings
  )
  return HistoryView(historyStore: store, historySettings: historySettings)
    .frame(width: 400, height: 400)
}

#Preview("Empty") {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("preview-history-empty")
  try? FileManager.default.removeItem(at: dir)
  let store = HistoryStore(directoryURL: dir)
  let historySettings = HistorySettings(
    defaults: UserDefaults(suiteName: "preview-history-empty")!
  )
  return HistoryView(historyStore: store, historySettings: historySettings)
    .frame(width: 400, height: 400)
}
