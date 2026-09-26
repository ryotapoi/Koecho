import KoechoCore
import SwiftUI

struct InputPanelScriptStrip: View {
  let scripts: [Script]
  let selectedScript: Script?
  let isRunningScript: Bool
  let hasPromptScript: Bool
  var onExecuteScript: (Script) async -> Void
  var onReorderScripts: ([Script]) -> Void

  private var isReorderingDisabled: Bool {
    isRunningScript || hasPromptScript
  }

  static func isExecutionDisabled(
    isRunningScript: Bool,
    hasPromptScript: Bool,
    selectedScriptID: UUID?,
    scriptID: UUID
  ) -> Bool {
    isRunningScript || (hasPromptScript && selectedScriptID != scriptID)
  }

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
          scriptButtons
        }
        .scrollIndicators(.hidden)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 8)
  }

  @ViewBuilder
  private var scriptButtons: some View {
    HStack(spacing: 8) {
      ForEach(scripts) { script in
        scriptButton(for: script)
      }
      .reorderable()
    }
    .reorderContainer(for: Script.self, isEnabled: !isReorderingDisabled) { difference in
      let destination: InputPanelScriptReorder.Destination
      switch difference.destination.position {
      case .before(let id):
        destination = .before(id)
      case .end:
        destination = .end
      }
      onReorderScripts(
        InputPanelScriptReorder.reordered(
          scripts: scripts,
          sourceIDs: difference.sources,
          destination: destination
        )
      )
    }
    .padding(.vertical, 1)
  }

  private func scriptButton(for script: Script) -> some View {
    let label = ScriptPresentation.label(for: script)
    let symbol = ScriptPresentation.symbolName(for: script)
    let identification = ScriptPresentation.identification(for: script)
    return Button {
      Task { await onExecuteScript(script) }
    } label: {
      HStack(spacing: 4) {
        if !symbol.isEmpty { Image(systemName: symbol) }
        if !label.isEmpty { Text(label) }
      }
    }
    .buttonStyle(.koechoToolbar(isSelected: selectedScript?.id == script.id))
    .help(identification)
    .accessibilityLabel(identification)
    .disabled(
      Self.isExecutionDisabled(
        isRunningScript: isRunningScript,
        hasPromptScript: hasPromptScript,
        selectedScriptID: selectedScript?.id,
        scriptID: script.id
      )
    )
  }
}

enum InputPanelScriptReorder {
  enum Destination {
    case before(UUID)
    case end
  }

  static func reordered(
    scripts: [Script],
    sourceIDs: [UUID],
    destination: Destination
  ) -> [Script] {
    let movingIDs = Set(sourceIDs)
    guard !movingIDs.isEmpty else { return scripts }

    let moved = scripts.filter { movingIDs.contains($0.id) }
    guard !moved.isEmpty else { return scripts }

    var remaining = scripts.filter { !movingIDs.contains($0.id) }
    switch destination {
    case .before(let id):
      let insertionIndex = remaining.firstIndex { $0.id == id } ?? remaining.endIndex
      remaining.insert(contentsOf: moved, at: insertionIndex)
    case .end:
      remaining.append(contentsOf: moved)
    }
    return remaining
  }
}

#Preview("Built-in Displays") {
  InputPanelScriptStrip(
    scripts: [
      Script(id: UUID(), builtin: BuiltinScript(feature: .decreaseIndent, indentationWidth: .two)!),
      Script(
        id: UUID(),
        builtin: BuiltinScript(feature: .increaseIndent, indentationWidth: .four)!,
        display: .init(name: "More indent", symbolName: "")
      ),
      Script(
        id: UUID(),
        builtin: BuiltinScript(feature: .blockQuote)!,
        display: .init(name: "Quote", symbolName: "star")
      ),
    ],
    selectedScript: nil,
    isRunningScript: false,
    hasPromptScript: false,
    onExecuteScript: { _ in },
    onReorderScripts: { _ in }
  )
  .frame(width: 600)
}
