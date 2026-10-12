import SwiftUI

struct HistorySearchField: View {
  @Binding var searchText: String

  var body: some View {
    TextField("Search history", text: $searchText)
      .textFieldStyle(.roundedBorder)
      .controlSize(.small)
  }
}
