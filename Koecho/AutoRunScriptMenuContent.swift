import KoechoCore
import SwiftUI

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
          Text("✓ \(ScriptPresentation.identification(for: script))")
        } else {
          Text("  \(ScriptPresentation.identification(for: script))")
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("With Scripts") {
  let defaults = UserDefaults(suiteName: "preview-autoRun-withScripts")!
  let settings = ScriptSettings(defaults: defaults)
  settings.scripts = [
    Script(name: "Format", scriptPath: "format.sh"),
    Script(name: "Summarize", scriptPath: "sum.sh"),
  ]
  return Menu("Auto-run") {
    AutoRunScriptMenuContent(scriptSettings: settings)
  }
  .frame(width: 200, height: 100)
}
