import KoechoCore
import SwiftUI

struct ScriptManagementView: View {
  @Bindable var settings: ScriptSettings
  @State private var selection: UUID?
  @State private var isResetConfirmationPresented = false

  var body: some View {
    VStack(spacing: 0) {
      if settings.isScriptsProtected {
        ScriptListProtectionNotice {
          isResetConfirmationPresented = true
        }
      }
      HStack(spacing: 0) {
        scriptList
          .frame(width: 200)
        Divider()
        scriptDetail
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .confirmationDialog(
      "Reset Scripts?",
      isPresented: $isResetConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("Reset Scripts", role: .destructive) {
        selection = nil
        settings.resetScripts()
      }
    } message: {
      Text("This permanently discards the unreadable saved scripts and starts with an empty list.")
    }
  }

  private var scriptList: some View {
    List(selection: $selection) {
      ForEach(settings.scripts) { script in
        Label(
          ScriptPresentation.label(for: script),
          systemImage: ScriptPresentation.symbolName(for: script)
        )
          .tag(script.id)
      }
      .onMove { source, destination in
        settings.moveScripts(from: source, to: destination)
      }
    }
      .safeAreaInset(edge: .bottom) {
      HStack {
        Menu {
          Button("Custom Script", action: addCustomScript)
          Menu("Built-in Feature") {
            ForEach(builtinScriptCandidates.indices, id: \.self) { index in
              let builtin = builtinScriptCandidates[index]
              Button(builtin.displayName) {
                addBuiltinScript(builtin)
              }
              .disabled(isBuiltinScriptRegistered(builtin))
            }
          }
        } label: {
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
    .disabled(settings.isScriptsProtected)
  }

  @ViewBuilder
  private var scriptDetail: some View {
    if settings.isScriptsProtected {
      Text("Scripts are protected until you reset them.")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let id = selection, let binding = scriptBinding(for: id) {
      ScriptEditView(script: binding)
    } else {
      Text("Select a script to edit")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func scriptBinding(for id: UUID) -> Binding<Script>? {
    guard let script = settings.scripts.first(where: { $0.id == id }) else { return nil }
    return Binding(
      get: { settings.scripts.first(where: { $0.id == id }) ?? script },
      set: { settings.updateScript($0) }
    )
  }

  private func addCustomScript() {
    let script = Script(name: String(localized: "New Script"), scriptPath: "")
    settings.addScript(script)
    selection = script.id
  }

  private var builtinScriptCandidates: [BuiltinScript] {
    BuiltinScriptFeature.allCases.flatMap { feature in
      feature.supportsIndentationWidth
        ? [
          BuiltinScript(feature: feature, indentationWidth: .two)!,
          BuiltinScript(feature: feature, indentationWidth: .four)!,
        ]
        : [BuiltinScript(feature: feature)!]
    }
  }

  private func addBuiltinScript(_ builtin: BuiltinScript) {
    guard !isBuiltinScriptRegistered(builtin) else { return }

    let script = Script(id: UUID(), builtin: builtin)
    settings.addScript(script)
    selection = script.id
  }

  private func isBuiltinScriptRegistered(_ builtin: BuiltinScript) -> Bool {
    settings.scripts.contains { $0.builtin == builtin }
  }

  private func deleteSelectedScript() {
    guard let id = selection else { return }
    selection = nil
    settings.deleteScript(id: id)
  }
}

private struct ScriptListProtectionNotice: View {
  let reset: () -> Void

  var body: some View {
    HStack {
      Label("Saved scripts could not be read. Editing is disabled to protect the saved data.", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Spacer()
      Button("Reset Scripts", role: .destructive, action: reset)
    }
    .padding()
    .background(.quaternary)
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
