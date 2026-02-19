import SwiftUI

struct InputPanelContent: View {
    @Bindable var appState: AppState
    var onExecuteScript: (Script) async -> Void
    var onCancelPrompt: () -> Void
    var onApplyReplacementRules: () -> Void = {}
    var onPromptFocused: () -> Void = {}
    var onAddReplacementRule: (ReplacementRule) -> Void = { _ in }
    var onTextChanged: (String) -> Void = { _ in }
    var onTextCommitted: () -> Void = {}
    var onTextViewCreated: (DictationTextView) -> Void = { _ in }
    var onFocusTextEditor: () -> Void = {}

    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            DictationTextEditor(
                text: appState.inputText,
                isDisabled: appState.isRunningScript,
                onTextChanged: onTextChanged,
                onTextCommitted: onTextCommitted,
                onAddReplacementRule: { pattern in
                    appState.pendingReplacementPattern = pattern
                },
                onViewCreated: onTextViewCreated
            )
            .frame(minHeight: 60, maxHeight: 300)
            .popover(
                isPresented: Binding(
                    get: { appState.pendingReplacementPattern != nil },
                    set: { if !$0 { appState.pendingReplacementPattern = nil } }
                )
            ) {
                if let pattern = appState.pendingReplacementPattern {
                    AddReplacementRuleView(
                        pattern: pattern,
                        onAdd: { rule in
                            onAddReplacementRule(rule)
                        },
                        onCancel: {
                            appState.pendingReplacementPattern = nil
                        }
                    )
                }
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
        .onChange(of: appState.promptScript) {
            if appState.promptScript != nil {
                isPromptFocused = true
                onPromptFocused()
            } else {
                isPromptFocused = false
                onFocusTextEditor()
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
                .focused($isPromptFocused)
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
        if let shortcut = appState.settings.replacementShortcutKey {
            "Apply replacement rules (\(shortcut.displayName))"
        } else {
            "Apply replacement rules"
        }
    }

    private func shortcutHelpText(for script: Script) -> String {
        if let shortcut = script.shortcutKey {
            "\(script.name) (\(shortcut.displayName))"
        } else {
            script.name
        }
    }
}
