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
                scriptButtonBar
            }

            if !eligibleScripts.isEmpty {
                autoRunPicker
            }

            if appState.promptScript != nil {
                promptInputView
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

    private var scriptButtonBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(appState.settings.script.scripts) { script in
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

    private var eligibleScripts: [Script] {
        appState.settings.script.scripts.filter { !$0.requiresPrompt }
    }

    private var autoRunPicker: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("On confirm:")
                .font(.callout)
                .foregroundStyle(.secondary)
            Menu {
                Button {
                    appState.settings.script.autoRunScriptId = nil
                } label: {
                    if appState.settings.script.autoRunScriptId == nil {
                        Text("✓ None")
                    } else {
                        Text("  None")
                    }
                }
                Divider()
                ForEach(eligibleScripts) { script in
                    Button {
                        appState.settings.script.autoRunScriptId = script.id
                    } label: {
                        if appState.settings.script.autoRunScriptId == script.id {
                            Text("✓ \(script.name)")
                        } else {
                            Text("  \(script.name)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(appState.settings.script.autoRunScript?.name ?? "None")
                        .font(.callout)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(autoRunShortcutHelpText)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private var autoRunShortcutHelpText: String {
        if let shortcut = appState.settings.script.autoRunShortcutKey {
            "Cycle auto-run script selection (\(shortcut.displayName))"
        } else {
            "Cycle auto-run script selection"
        }
    }

    private var replacementShortcutHelpText: String {
        if let shortcut = appState.settings.replacement.replacementShortcutKey {
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
