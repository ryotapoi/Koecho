import SwiftUI

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
                    Image(systemName: "plus")
                        .frame(width: 16, height: 16)
                }
                Button(action: deleteSelectedScript) {
                    Image(systemName: "minus")
                        .frame(width: 16, height: 16)
                }
                .disabled(selection == nil)
                Spacer()
            }
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
        let script = Script(name: "New Script", scriptPath: "")
        settings.addScript(script)
        selection = script.id
    }

    private func deleteSelectedScript() {
        guard let id = selection else { return }
        selection = nil
        settings.deleteScript(id: id)
    }
}
