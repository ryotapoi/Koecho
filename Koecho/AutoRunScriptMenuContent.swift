import SwiftUI
import KoechoCore

struct AutoRunScriptMenuContent: View {
    @Bindable var scriptSettings: ScriptSettings

    var body: some View {
        Button {
            scriptSettings.autoRunScriptId = nil
        } label: {
            if scriptSettings.autoRunScriptId == nil {
                Text("✓ None")
            } else {
                Text("  None")
            }
        }
        Divider()
        ForEach(scriptSettings.eligibleAutoRunScripts) { script in
            Button {
                scriptSettings.autoRunScriptId = script.id
            } label: {
                if scriptSettings.autoRunScriptId == script.id {
                    Text("✓ \(script.name)")
                } else {
                    Text("  \(script.name)")
                }
            }
        }
    }
}
