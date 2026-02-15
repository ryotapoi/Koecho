import SwiftUI

struct InputPanelContent: View {
    @Bindable var appState: AppState
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        TextEditor(text: $appState.inputText)
            .focused($isTextEditorFocused)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minWidth: 300, maxWidth: 300, minHeight: 100, maxHeight: 400)
            .background(.ultraThinMaterial)
            .onAppear {
                isTextEditorFocused = true
            }
    }
}
