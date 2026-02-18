import SwiftUI

struct InputPanelContent: View {
    @Bindable var appState: AppState
    var onExecuteScript: (Script) async -> Void
    var onCancelPrompt: () -> Void
    var onApplyReplacementRules: () -> Void = {}
    var onPromptFocused: () -> Void = {}

    private enum FocusField {
        case textEditor
        case prompt
    }

    @FocusState private var focusedField: FocusField?

    var body: some View {
        VStack(spacing: 4) {
            TextEditor(text: $appState.inputText)
                .focused($focusedField, equals: .textEditor)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 300)
                .disabled(appState.isRunningScript)
                .onChange(of: appState.inputText) {
                    appState.errorMessage = nil
                }

            if !appState.settings.replacementRules.isEmpty {
                HStack {
                    Button {
                        onApplyReplacementRules()
                    } label: {
                        Label("Replace", systemImage: "arrow.2.squarepath")
                            .font(.caption)
                    }
                    .help(replacementShortcutHelpText)
                    .disabled(appState.isRunningScript)
                    Spacer()
                }
                .padding(.horizontal, 8)
            }

            if !appState.settings.scripts.isEmpty {
                scriptButtonBar
            }

            if appState.promptScript != nil {
                promptInputView
            }

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
        .frame(minWidth: 300, maxWidth: 300)
        .background(.ultraThinMaterial)
        .onChange(of: appState.isInputPanelVisible) {
            if appState.isInputPanelVisible {
                focusedField = .textEditor
            }
        }
        .onChange(of: appState.promptScript) {
            if appState.promptScript != nil {
                focusedField = .prompt
                onPromptFocused()
            } else {
                focusedField = .textEditor
            }
        }
    }

    private var scriptButtonBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(appState.settings.scripts) { script in
                    Button {
                        Task { await onExecuteScript(script) }
                    } label: {
                        Text(script.name)
                            .font(.caption)
                    }
                    .help(shortcutHelpText(for: script))
                    .disabled(appState.isRunningScript || appState.promptScript != nil)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var promptInputView: some View {
        HStack(spacing: 4) {
            TextField("Prompt", text: $appState.promptText)
                .focused($focusedField, equals: .prompt)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit {
                    if let script = appState.promptScript {
                        Task { await onExecuteScript(script) }
                    }
                }

            Button {
                if let script = appState.promptScript {
                    Task { await onExecuteScript(script) }
                }
            } label: {
                Text("Run")
                    .font(.caption)
            }
            .disabled(appState.isRunningScript)

            Button {
                onCancelPrompt()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .disabled(appState.isRunningScript)
        }
        .padding(.horizontal, 8)
    }

    private var replacementShortcutHelpText: String {
        if let key = appState.settings.replacementShortcutKey {
            "Apply replacement rules (Ctrl+\(key.uppercased()))"
        } else {
            "Apply replacement rules"
        }
    }

    private func shortcutHelpText(for script: Script) -> String {
        if let key = script.shortcutKey {
            "\(script.name) (Ctrl+\(key))"
        } else {
            script.name
        }
    }
}
