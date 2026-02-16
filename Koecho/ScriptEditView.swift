import SwiftUI

struct ScriptEditView: View {
    @Binding var script: Script

    var body: some View {
        Form {
            TextField("Name", text: $script.name)

            HStack {
                TextField("Script Path", text: $script.scriptPath)
                Button("Choose...") {
                    chooseFile()
                }
            }

            TextField(
                "Shortcut Key (Ctrl+)",
                text: shortcutKeyBinding
            )
            .help("Single character, used as Ctrl+<key>")

            Toggle("Requires Prompt", isOn: $script.requiresPrompt)
        }
        .formStyle(.grouped)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var shortcutKeyBinding: Binding<String> {
        Binding(
            get: { script.shortcutKey ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    script.shortcutKey = nil
                } else {
                    script.shortcutKey = String(newValue.suffix(1))
                }
            }
        )
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            script.scriptPath = url.path
        }
    }
}
