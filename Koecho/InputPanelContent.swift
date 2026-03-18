import SwiftUI
import KoechoCore
import KoechoPlatform

struct InputPanelContent: View {
    @Bindable var appState: AppState
    var onExecuteScript: (Script) async -> Void
    var onCancelPrompt: () -> Void
    var onApplyReplacementRules: () -> Void = {}
    var onPromptFocused: () -> Void = {}
    var onAddReplacementRule: (ReplacementRule) -> Void = { _ in }
    var onTextChanged: (String) -> Void = { _ in }
    var onTextCommitted: () -> Void = {}
    var onTextViewCreated: (VoiceInputTextView) -> Void = { _ in }
    var onFocusTextEditor: () -> Void = {}

    @FocusState private var isPromptFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            VoiceInputTextEditor(
                text: appState.inputText,
                isDisabled: appState.isRunningScript,
                onTextChanged: onTextChanged,
                onTextCommitted: onTextCommitted,
                onAddReplacementRule: { pattern in
                    appState.pendingReplacementPattern = pattern
                },
                onViewCreated: onTextViewCreated
            )
            .opacity(appState.voiceEngineStatus != nil ? 0.5 : 1.0)
            .frame(minHeight: 60, maxHeight: CGFloat.infinity)
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

            if !appState.settings.replacement.replacementRules.isEmpty {
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

            if !appState.settings.script.scripts.isEmpty {
                ScriptButtonBar(
                    scripts: appState.settings.script.scripts,
                    isDisabled: appState.isRunningScript || appState.promptScript != nil,
                    onExecuteScript: onExecuteScript
                )
            }

            if !appState.settings.script.eligibleAutoRunScripts.isEmpty {
                AutoRunPicker(scriptSettings: appState.settings.script)
            }

            if appState.promptScript != nil {
                PromptInputView(
                    promptText: $appState.promptText,
                    promptScript: appState.promptScript,
                    isRunningScript: appState.isRunningScript,
                    onExecuteScript: onExecuteScript,
                    onCancelPrompt: onCancelPrompt,
                    isFocused: $isPromptFocused
                )
            }

            if let status = appState.voiceEngineStatus {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            }

            if appState.settings.voiceInput.effectiveVoiceInputMode == .off {
                HStack(spacing: 4) {
                    Image(systemName: "mic.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Voice input is off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            }

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity)
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

    private var replacementShortcutHelpText: String {
        if let shortcut = appState.settings.replacement.replacementShortcutKey {
            "Apply replacement rules (\(shortcut.displayName))"
        } else {
            "Apply replacement rules"
        }
    }

}
