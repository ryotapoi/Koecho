import KoechoCore
import SwiftUI

struct AutoRunScriptLabel: View {
  let script: Script?

  var body: some View {
    if let script {
      let symbol = ScriptPresentation.symbolName(for: script)
      let title = ScriptPresentation.label(for: script)
      if title.isEmpty {
        Label(ScriptPresentation.identification(for: script), systemImage: symbol)
          .labelStyle(.iconOnly)
      } else if symbol.isEmpty {
        Text(title)
      } else {
        Label(title, systemImage: symbol)
          .labelStyle(.titleAndIcon)
      }
    } else {
      Label("None", systemImage: "play.slash")
        .labelStyle(.titleAndIcon)
    }
  }
}
