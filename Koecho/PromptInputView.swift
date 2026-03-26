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

// MARK: - Previews

#Preview("Empty") {
    struct Wrapper: View {
        @FocusState var isFocused: Bool
        var body: some View {
            PromptInputView(
                promptText: .constant(""),
                promptScript: Script(name: "AI Rewrite", scriptPath: "ai.sh"),
                isRunningScript: false,
                onExecuteScript: { _ in },
                onCancelPrompt: {},
                isFocused: $isFocused
            )
        }
    }
    return Wrapper()
        .frame(width: 300)
}

#Preview("Running") {
    struct Wrapper: View {
        @FocusState var isFocused: Bool
        var body: some View {
            PromptInputView(
                promptText: .constant("箇条書きにして"),
                promptScript: Script(name: "AI Rewrite", scriptPath: "ai.sh"),
                isRunningScript: true,
                onExecuteScript: { _ in },
                onCancelPrompt: {},
                isFocused: $isFocused
            )
        }
    }
    return Wrapper()
        .frame(width: 300)
}
