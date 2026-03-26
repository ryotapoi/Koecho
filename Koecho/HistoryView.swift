import SwiftUI
import KoechoCore
import KoechoPlatform

struct HistoryView: View {
    var historyStore: HistoryStore
    @State private var searchText = ""
    @State private var copiedEntryID: UUID?
    @State private var resetCopiedTask: Task<Void, Never>?
    @State private var popoverEntryID: UUID?

    private var filteredEntries: [HistoryEntry] {
        if searchText.isEmpty {
            return historyStore.entries
        }
        return historyStore.entries.filter {
            $0.text.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(filteredEntries) { entry in
                    HistoryRow(
                        entry: entry,
                        isCopied: copiedEntryID == entry.id,
                        onCopy: { copyEntry(entry) }
                    )
                    .contextMenu {
                        Button("Copy") { copyEntry(entry) }
                        Button("Show Full Text") {
                            popoverEntryID = entry.id
                        }
                    }
                    .popover(isPresented: Binding(
                        get: { popoverEntryID == entry.id },
                        set: { if !$0 { popoverEntryID = nil } }
                    )) {
                        FullTextPopoverContent(text: entry.text)
                    }
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search history")

            HStack {
                Button("Clear All") {
                    historyStore.clear()
                }
                .disabled(historyStore.entries.isEmpty)
                Spacer()
                Text("\(historyStore.entries.count) entries")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(8)
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
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .lineLimit(2)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isCopied {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(entry.timestamp, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FullTextPopoverContent: View {
    let text: String
    private let maxPopoverHeight: CGFloat = 600
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            Text(text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 300, maxWidth: 500, alignment: .leading)
                .padding()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
        }
        .frame(height: contentHeight > 0 ? min(contentHeight, maxPopoverHeight) : nil)
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
        text: "A longer entry that might wrap to multiple lines. This tests the line limit behavior of the history row.",
        settings: historySettings
    )
    return HistoryView(historyStore: store)
        .frame(width: 400, height: 400)
}

#Preview("Empty") {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("preview-history-empty")
    try? FileManager.default.removeItem(at: dir)
    let store = HistoryStore(directoryURL: dir)
    return HistoryView(historyStore: store)
        .frame(width: 400, height: 400)
}
