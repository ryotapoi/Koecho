import KoechoCore
import SwiftUI

struct InputPanelScriptStrip: View {
  let scripts: [Script]
  let selectedScript: Script?
  let isRunningScript: Bool
  let hasPromptScript: Bool
  var onExecuteScript: (Script) async -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("SCRIPTS")
        .font(.caption.weight(.bold))
        .foregroundStyle(.tertiary)
        .tracking(1)

      if scripts.isEmpty {
        Text("まだありません — 設定で追加できます")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      } else {
        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            ForEach(scripts) { script in
              let label = ScriptPresentation.label(for: script)
              Button {
                Task { await onExecuteScript(script) }
              } label: {
                if script.kind == .builtin {
                  Image(systemName: ScriptPresentation.symbolName(for: script))
                } else {
                  Label {
                    Text(label)
                  } icon: {
                    Image(systemName: ScriptPresentation.symbolName(for: script))
                  }
                }
              }
              .buttonStyle(.koechoToolbar(isSelected: selectedScript?.id == script.id))
              .help(label)
              .accessibilityLabel(label)
              .disabled(
                isRunningScript || (hasPromptScript && selectedScript?.id != script.id)
              )
            }
          }
          .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 8)
  }
}
