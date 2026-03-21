import SwiftUI
import KoechoCore

struct InputPanelToolbar: View {
    let replacementRules: [ReplacementRule]
    let scripts: [Script]
    @Bindable var scriptSettings: ScriptSettings
    let isRunningScript: Bool
    let hasPromptScript: Bool
    var onApplyReplacementRules: () -> Void
    var onExecuteScript: (Script) async -> Void
    let replacementShortcutKey: ShortcutKey?

    private var hasAutoRunScripts: Bool {
        !scriptSettings.eligibleAutoRunScripts.isEmpty
    }

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    if !replacementRules.isEmpty {
                        Button {
                            onApplyReplacementRules()
                        } label: {
                            Label("Replace", systemImage: "arrow.2.squarepath")
                                .font(.caption)
                        }
                        .help(helpText(String(localized: "Apply replacement rules"), shortcut: replacementShortcutKey))
                        .disabled(isRunningScript)
                    }

                    if !replacementRules.isEmpty && !scripts.isEmpty {
                        Divider()
                            .frame(height: 14)
                    }

                    ForEach(scripts) { script in
                        Button {
                            Task { await onExecuteScript(script) }
                        } label: {
                            Text(script.name)
                                .font(.caption)
                        }
                        .frame(minWidth: 32)
                        .help(helpText(script.name, shortcut: script.shortcutKey))
                        .disabled(isRunningScript || hasPromptScript)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, hasAutoRunScripts ? 0 : 8)
            }
            .scrollIndicators(.hidden)

            if hasAutoRunScripts {
                Divider()
                    .frame(height: 14)

                Menu {
                    AutoRunScriptMenuContent(scriptSettings: scriptSettings)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                        Text(scriptSettings.autoRunScript?.name ?? String(localized: "None"))
                            .font(.caption)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(helpText(String(localized: "Cycle auto-run script selection"), shortcut: scriptSettings.autoRunShortcutKey))
                .padding(.trailing, 8)
            }
        }
    }

    private func helpText(_ label: String, shortcut: ShortcutKey?) -> String {
        if let shortcut {
            "\(label) (\(shortcut.displayName))"
        } else {
            label
        }
    }
}
