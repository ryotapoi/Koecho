import SwiftUI
import KoechoCore

struct PromptInputView: View {
    @Binding var promptText: String
    let promptScript: Script?
    let isRunningScript: Bool
    var onExecuteScript: (Script) async -> Void
    var onCancelPrompt: () -> Void
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 4) {
            TextField("Prompt", text: $promptText)
                .focused(isFocused)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit {
                    if let script = promptScript {
                        Task { await onExecuteScript(script) }
                    }
                }

            Button {
                if let script = promptScript {
                    Task { await onExecuteScript(script) }
                }
            } label: {
                Text("Run")
                    .font(.caption)
            }
            .disabled(isRunningScript)

            Button {
                onCancelPrompt()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.caption)
            }
            .disabled(isRunningScript)
        }
        .padding(.horizontal, 8)
    }
}
