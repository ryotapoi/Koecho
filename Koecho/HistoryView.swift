import SwiftUI

struct HistoryView: View {
    var historyStore: HistoryStore
    @State private var searchText = ""
    @State private var copiedEntryID: UUID?
    @State private var popoverEntryID: UUID?

    private var filteredEntries: [HistoryEntry] {
        if searchText.isEmpty {
            return historyStore.entries
        }
        return historyStore.entries.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
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
                        ScrollView {
                            Text(entry.text)
                                .textSelection(.enabled)
                                .padding()
                                .frame(minWidth: 300, maxWidth: 500, alignment: .leading)
                        }
                        .frame(maxHeight: 400)
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        withAnimation {
            copiedEntryID = entry.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                if copiedEntryID == entry.id {
                    copiedEntryID = nil
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
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
        .onTapGesture { onCopy() }
    }
}
