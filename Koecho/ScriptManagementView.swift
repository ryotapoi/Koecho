import SwiftUI
import KoechoCore

struct ScriptManagementView: View {
    @Bindable var settings: ScriptSettings
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            scriptList
                .frame(width: 200)
            Divider()
            scriptDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var scriptList: some View {
        List(selection: $selection) {
            ForEach(settings.scripts) { script in
                Text(script.name)
                    .tag(script.id)
            }
            .onMove { source, destination in
                settings.moveScripts(from: source, to: destination)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: addScript) {
                    Label("Add Script", systemImage: "plus")
                        .frame(width: 16, height: 16)
                }
                Button(action: deleteSelectedScript) {
                    Label("Delete Script", systemImage: "minus")
                        .frame(width: 16, height: 16)
                }
                .disabled(selection == nil)
                Spacer()
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
    }

    @ViewBuilder
    private var scriptDetail: some View {
        if let id = selection, let binding = scriptBinding(for: id) {
            ScriptEditView(script: binding)
        } else {
            Text("Select a script to edit")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func scriptBinding(for id: UUID) -> Binding<Script>? {
        guard let index = settings.scripts.firstIndex(where: { $0.id == id }) else { return nil }
        return $settings.scripts[index]
    }

    private func addScript() {
        let script = Script(name: String(localized: "New Script"), scriptPath: "")
        settings.addScript(script)
        selection = script.id
    }

    private func deleteSelectedScript() {
        guard let id = selection else { return }
        selection = nil
        settings.deleteScript(id: id)
    }
}

// MARK: - Previews

#Preview("With Scripts") {
    let defaults = UserDefaults(suiteName: "preview-scriptMgmt-withScripts")!
    let settings = ScriptSettings(defaults: defaults)
    settings.scripts = [
        Script(name: "Format", scriptPath: "format.sh"),
        Script(name: "AI Rewrite", scriptPath: "ai.sh", requiresPrompt: true),
    ]
    return ScriptManagementView(settings: settings)
        .frame(width: 600, height: 400)
}

#Preview("Empty") {
    let defaults = UserDefaults(suiteName: "preview-scriptMgmt-empty")!
    let settings = ScriptSettings(defaults: defaults)
    settings.scripts = []
    return ScriptManagementView(settings: settings)
        .frame(width: 600, height: 400)
}
