import SwiftUI

struct ScriptEditView: View {
    @Binding var script: Script

    var body: some View {
        Form {
            TextField("Name", text: $script.name)

            HStack {
                TextField("Script Command", text: $script.scriptPath)
                    .help("Shell command to run. You can use arguments, pipes, and redirects. Quote paths with spaces: '/path/to/my script.sh' arg1")
                Button("Choose...") {
                    chooseFile()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Shortcut Key")
                    Spacer()
                    ShortcutKeyRecorder(shortcutKey: $script.shortcutKey)
                        .frame(width: 120)
                }
                Text("Avoid shortcuts used by other apps or the system")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Requires Prompt", isOn: $script.requiresPrompt)
        }
        .formStyle(.grouped)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            script.scriptPath = "'\(url.path.replacingOccurrences(of: "'", with: "'\\''"))'"
        }
    }
}
