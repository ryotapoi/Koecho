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
        VStack(spacing: 0) {
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

            if !appState.settings.replacement.replacementRules.isEmpty
                || !appState.settings.script.scripts.isEmpty
                || !appState.settings.script.eligibleAutoRunScripts.isEmpty {
                InputPanelToolbar(
                    replacementRules: appState.settings.replacement.replacementRules,
                    scripts: appState.settings.script.scripts,
                    scriptSettings: appState.settings.script,
                    isRunningScript: appState.isRunningScript,
                    hasPromptScript: appState.promptScript != nil,
                    onApplyReplacementRules: onApplyReplacementRules,
                    onExecuteScript: onExecuteScript,
                    replacementShortcutKey: appState.settings.replacement.replacementShortcutKey
                )
                .padding(.top, 6)
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
                .padding(.top, 4)
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
                .padding(.top, 4)
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
                .padding(.top, 4)
            }

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }

            Spacer()
                .frame(height: 4)
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

}
