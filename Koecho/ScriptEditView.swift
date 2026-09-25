import KoechoCore
import SwiftUI

struct ScriptEditView: View {
  @Binding var script: Script

  var body: some View {
    Form {
      LabeledContent("Type") {
        if script.kind == .custom {
          Text("Custom Script")
        } else {
          Text("Built-in Feature")
        }
      }

      if script.kind == .custom {
        TextField("Name", text: $script.name)

        HStack {
          TextField("Script Command", text: $script.scriptPath)
            .help(
              "Shell command to run. You can use arguments, pipes, and redirects. Quote paths with spaces: '/path/to/my script.sh' arg1"
            )
          Button("Choose...") {
            chooseFile()
          }
        }

        Toggle("Requires Prompt", isOn: $script.requiresPrompt)
      } else {
        builtinControls
      }

      shortcutControl
    }
    .formStyle(.grouped)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var builtinControls: some View {
    Picker("Feature", selection: builtinFeatureRawValueBinding) {
      ForEach(BuiltinScriptFeature.allCases, id: \.self) { feature in
        Text(feature.displayName).tag(feature.rawValue)
      }
    }

    if builtinFeature.supportsIndentationWidth {
      Picker("Indent Width", selection: builtinWidthRawValueBinding) {
        Text("2 spaces").tag(BuiltinScriptIndentationWidth.two.rawValue)
        Text("4 spaces").tag(BuiltinScriptIndentationWidth.four.rawValue)
      }
    }
  }

  private var shortcutControl: some View {
    HStack {
      Text("Shortcut Key")
      Spacer()
      ShortcutKeyRecorder(shortcutKey: $script.shortcutKey)
        .frame(width: 120)
    }
  }

  private var builtinFeature: BuiltinScriptFeature {
    script.builtin?.feature ?? .decreaseIndent
  }

  private var builtinFeatureRawValueBinding: Binding<String> {
    Binding(
      get: { builtinFeature.rawValue },
      set: { rawValue in
        guard let feature = BuiltinScriptFeature(rawValue: rawValue) else { return }
        replaceBuiltin(feature: feature, indentationWidth: defaultWidth(for: feature))
      }
    )
  }

  private var builtinWidthRawValueBinding: Binding<Int> {
    Binding(
      get: { script.builtin?.indentationWidth?.rawValue ?? BuiltinScriptIndentationWidth.two.rawValue },
      set: { rawValue in
        guard let width = BuiltinScriptIndentationWidth(rawValue: rawValue) else { return }
        replaceBuiltin(feature: builtinFeature, indentationWidth: width)
      }
    )
  }

  private func replaceBuiltin(
    feature: BuiltinScriptFeature,
    indentationWidth: BuiltinScriptIndentationWidth?
  ) {
    let width = feature.supportsIndentationWidth ? indentationWidth ?? .two : nil
    guard let builtin = BuiltinScript(feature: feature, indentationWidth: width) else { return }
    script = Script(id: script.id, builtin: builtin, shortcutKey: script.shortcutKey)
  }

  private func defaultWidth(for feature: BuiltinScriptFeature) -> BuiltinScriptIndentationWidth? {
    feature.supportsIndentationWidth ? script.builtin?.indentationWidth ?? .two : nil
  }

  private func chooseFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    if panel.runModal() == .OK, let url = panel.url {
      script.scriptPath = "'\(url.path.replacing("'", with: "'\\''"))'"
    }
  }
}

// MARK: - Previews

#Preview("Filled") {
  @Previewable @State var script = Script(
    name: "Format Text",
    scriptPath: "'/usr/local/bin/format.sh' --mode=markdown",
    shortcutKey: ShortcutKey(modifiers: [.control], character: "f")
  )
  ScriptEditView(script: $script)
    .frame(width: 400, height: 300)
}

#Preview("Empty") {
  @Previewable @State var script = Script(name: "", scriptPath: "")
  ScriptEditView(script: $script)
    .frame(width: 400, height: 300)
}

#Preview("Requires Prompt") {
  @Previewable @State var script = Script(
    name: "AI Rewrite",
    scriptPath: "ai-rewrite.sh",
    requiresPrompt: true
  )
  ScriptEditView(script: $script)
    .frame(width: 400, height: 300)
}
