import KoechoCore
import SwiftUI

struct HistoryList: View {
  let entries: [HistoryEntry]
  let copiedEntryID: UUID?
  @Binding var popoverEntryID: UUID?
  let onCopy: (HistoryEntry) -> Void

  var body: some View {
    GeometryReader { geometry in
      List {
        ForEach(entries) { entry in
          HistoryRow(
            entry: entry,
            isCopied: copiedEntryID == entry.id,
            onCopy: { onCopy(entry) }
          )
          .contextMenu {
            Button("Copy") { onCopy(entry) }
            Button("Show Full Text") {
              popoverEntryID = entry.id
            }
          }
          .popover(
            isPresented: Binding(
              get: { popoverEntryID == entry.id },
              set: { if !$0 { popoverEntryID = nil } }
            )
          ) {
            FullTextPopoverContent(text: entry.text)
          }
          .listRowInsets(.horizontal, 10)
          .listRowBackground(Color.clear)
          .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
          .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
        }
      }
      .listStyle(.inset)
      .contentMargins(0, for: .scrollContent)
      .scrollContentBackground(.hidden)
      .background(.fill.tertiary, in: .rect(cornerRadius: 10))
      .clipShape(.rect(cornerRadius: 10))
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
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

        HStack {
          if isCopied {
            Text("Copied!")
              .font(.caption)
              .foregroundStyle(.green)
          }

          Text(entry.timestamp, format: .dateTime)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
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

