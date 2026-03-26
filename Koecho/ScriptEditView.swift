import SwiftUI
import KoechoCore

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
            script.scriptPath = "'\(url.path.replacing("'", with: "'\\''"))'"
        }
    }
}

// MARK: - Previews

#Preview("Filled") {
    @Previewable @State var script = Script(
        name: "Format Text",
        scriptPath: "'/usr/local/bin/format.sh' --mode=markdown",
        shortcutKey: ShortcutKey(modifiers: [.control], character: "f")
    )
    ScriptEditView(script: $script)
        .frame(width: 400, height: 300)
}

#Preview("Empty") {
    @Previewable @State var script = Script(name: "", scriptPath: "")
    ScriptEditView(script: $script)
        .frame(width: 400, height: 300)
}

#Preview("Requires Prompt") {
    @Previewable @State var script = Script(
        name: "AI Rewrite",
        scriptPath: "ai-rewrite.sh",
        requiresPrompt: true
    )
    ScriptEditView(script: $script)
        .frame(width: 400, height: 300)
}
