import SwiftUI

struct HistoryFooter: View {
  let entryCount: Int
  let onClear: () -> Void

  var body: some View {
    HStack {
      Button("Clear All", action: onClear)
        .disabled(entryCount == 0)
      Spacer()
      Text("\(entryCount) entries")
        .foregroundStyle(.secondary)
        .font(.caption)
    }
  }
}
