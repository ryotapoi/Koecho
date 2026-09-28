import KoechoCore
import SwiftUI

struct AutoRunScriptMenuContent: View {
  @Bindable var scriptSettings: ScriptSettings

  var body: some View {
    Toggle(isOn: Binding(
      get: { scriptSettings.autoRunScriptId == nil },
      set: { _ in scriptSettings.autoRunScriptId = nil }
    )) {
      AutoRunScriptLabel(script: nil)
    }
    Divider()
    ForEach(scriptSettings.eligibleAutoRunScripts) { script in
      Toggle(isOn: Binding(
        get: { scriptSettings.autoRunScriptId == script.id },
        set: { _ in scriptSettings.autoRunScriptId = script.id }
      )) {
        AutoRunScriptLabel(script: script)
      }
    }
  }
}

// MARK: - Previews

#Preview("With Scripts") {
  let defaults = UserDefaults(suiteName: "preview-autoRun-withScripts")!
  let settings = ScriptSettings(defaults: defaults)
  var both = Script(name: "Format", scriptPath: "format.sh")
  both.display = .init(name: "Format", symbolName: "text.alignleft")
  var symbolOnly = Script(name: "Symbol only", scriptPath: "symbol.sh")
  symbolOnly.display = .init(name: "", symbolName: "star")
  var titleOnly = Script(name: "Title only", scriptPath: "title.sh")
  titleOnly.display = .init(name: "Title only", symbolName: "")
  settings.scripts = [both, symbolOnly, titleOnly]
  return Menu("Auto-run") {
    AutoRunScriptMenuContent(scriptSettings: settings)
  }
  .frame(width: 200, height: 100)
}
