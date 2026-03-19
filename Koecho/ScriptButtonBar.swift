import SwiftUI
import KoechoCore

struct ScriptButtonBar: View {
    let scripts: [Script]
    let isDisabled: Bool
    var onExecuteScript: (Script) async -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(scripts) { script in
                    Button {
                        Task { await onExecuteScript(script) }
                    } label: {
                        Text(script.name)
                            .font(.caption)
                    }
                    .help(shortcutHelpText(for: script))
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func shortcutHelpText(for script: Script) -> String {
        if let shortcut = script.shortcutKey {
            "\(script.name) (\(shortcut.displayName))"
        } else {
            script.name
        }
    }
}
