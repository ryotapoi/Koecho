import KoechoCore
import SwiftUI

struct PromptInputView: View {
  @Binding var promptText: String
  @Binding var volatilePromptText: String
  let promptScript: Script?
  let isRunningScript: Bool
  var onExecuteScript: (Script) async -> Void
  var onCancelPrompt: () -> Void
  var isFocused: FocusState<Bool>.Binding

  private var displayedPromptText: Binding<String> {
    Binding(
      get: { promptText + volatilePromptText },
      set: {
        promptText = $0
        volatilePromptText = ""
      }
    )
  }

  var body: some View {
    HStack(spacing: 10) {
      if let promptScript {
        Label {
          Text(promptScript.name)
        } icon: {
          Image(systemName: "text.bubble.fill")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color(nsColor: .windowBackgroundColor))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.primary.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
      }

      TextField("Prompt", text: displayedPromptText)
        .focused(isFocused)
        .textFieldStyle(.plain)
        .font(.body)
        .onSubmit {
          executePrompt()
        }

      Button(action: executePrompt) {
        Label("Run", systemImage: "play.fill")
      }
      .buttonStyle(.koechoToolbar(isPrimary: true))
      .disabled(isRunningScript || promptScript == nil)

      Button {
        onCancelPrompt()
      } label: {
        Label("Cancel", systemImage: "xmark")
          .labelStyle(.iconOnly)
          .font(.body.weight(.medium))
          .frame(width: 44, height: 30)
          .foregroundStyle(isRunningScript ? .secondary : .primary)
          .background(
            Color.primary.opacity(isRunningScript ? 0.05 : 0.08),
            in: RoundedRectangle(cornerRadius: 8)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.primary.opacity(isRunningScript ? 0.08 : 0.12), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .disabled(isRunningScript)
    }
    .padding(8)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    }
  }

  private func executePrompt() {
    if let script = promptScript {
      Task { await onExecuteScript(script) }
    }
  }
}

// MARK: - Previews

#Preview("Empty") {
  struct Wrapper: View {
    @FocusState var isFocused: Bool
    var body: some View {
      PromptInputView(
        promptText: .constant(""),
        volatilePromptText: .constant(""),
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
        volatilePromptText: .constant(""),
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
