import SwiftUI
import KoechoCore

struct AutoRunPicker: View {
    @Bindable var scriptSettings: ScriptSettings

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("On confirm:")
                .font(.callout)
                .foregroundStyle(.secondary)
            Menu {
                AutoRunScriptMenuContent(scriptSettings: scriptSettings)
            } label: {
                HStack(spacing: 2) {
                    Text(scriptSettings.autoRunScript?.name ?? "None")
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
        if let shortcut = scriptSettings.autoRunShortcutKey {
            "Cycle auto-run script selection (\(shortcut.displayName))"
        } else {
            "Cycle auto-run script selection"
        }
    }
}
