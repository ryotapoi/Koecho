import KoechoCore
import SwiftUI

struct ScriptEditView: View {
  @Binding var script: Script
  @State private var displayName: String
  @State private var symbolName: String
  @State private var isIconPickerPresented = false

  init(script: Binding<Script>) {
    _script = script
    _displayName = State(initialValue: ScriptPresentation.label(for: script.wrappedValue))
    _symbolName = State(initialValue: ScriptPresentation.symbolName(for: script.wrappedValue))
  }

  private var canSaveDisplay: Bool {
    ScriptPresentation.validatedDisplay(name: displayName, symbolName: symbolName) != nil
  }
  private var iconDescription: String {
    symbolName.isEmpty ? String(localized: "Choose Icon") : String(localized: "Icon: \(symbolName)")
  }

  var body: some View {
    Form {
      HStack(spacing: 12) {
        Text(script.kind == .custom ? LocalizedStringResource("Custom") : LocalizedStringResource("Built-in"))
          .frame(width: 100, alignment: .leading)

        HStack(spacing: 8) {
          Button {
            isIconPickerPresented = true
          } label: {
            Image(systemName: symbolName.isEmpty ? "plus" : symbolName)
              .frame(width: 18)
          }
          .accessibilityLabel(iconDescription)
          .help(iconDescription)
          .popover(isPresented: $isIconPickerPresented, arrowEdge: .trailing) {
            ScriptIconPicker(
              selectedSymbol: symbolName,
              canChooseNone: !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) { selected in
              symbolName = selected
              saveDisplayIfValid()
              isIconPickerPresented = false
            }
          }

          TextField("Display Name", text: $displayName)
            .labelsHidden()
            .accessibilityLabel("Display Name")
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 0, maxWidth: .infinity)
            .onChange(of: displayName) { _, _ in saveDisplayIfValid() }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
      }

      if script.kind == .custom {
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
        if let builtin = script.builtin {
          LabeledContent("Feature") {
            if let width = builtin.indentationWidth {
              Text("\(builtin.feature.displayName) (\(width.rawValue))")
            } else {
              Text(builtin.feature.displayName)
            }
          }
        }
      }

      if !canSaveDisplay {
        Text("Enter a display name or SF Symbol. Your display changes have not been saved.")
          .foregroundStyle(.red)
      }

      shortcutControl
    }
    .formStyle(.grouped)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private var shortcutControl: some View {
    HStack {
      Text("Shortcut Key")
      Spacer()
      ShortcutKeyRecorder(shortcutKey: $script.shortcutKey)
        .frame(width: 120)
    }
  }

  private func saveDisplayIfValid() {
    guard let display = ScriptPresentation.validatedDisplay(name: displayName, symbolName: symbolName) else { return }
    let name = display.name
    let symbol = display.symbolName
    let currentName = ScriptPresentation.label(for: script)
    let currentSymbol = ScriptPresentation.symbolName(for: script)
    guard name != currentName || symbol != currentSymbol else { return }
    script.display = display
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

enum ScriptSymbolPresets {
  struct Group {
    let id: String
    let title: LocalizedStringResource
    let symbols: [String]
  }

  static let groups = [
    Group(id: "numbers", title: "Numbers", symbols: ["1.square", "2.square", "3.square", "4.square", "5.square", "6.square", "7.square", "8.square", "9.square", "0.square"]),
    Group(id: "shapes", title: "Shapes & Symbols", symbols: ["circle", "triangle", "square", "star", "heart", "sparkles", "bolt", "checkmark.rectangle"]),
    Group(id: "arrows", title: "Arrows", symbols: ["arrow.up", "arrow.down", "arrow.left", "arrow.right"]),
    Group(id: "text", title: "Text", symbols: ["text.alignleft", "text.aligncenter", "text.alignright", "list.bullet"]),
    Group(id: "actions", title: "Actions", symbols: ["doc.on.clipboard", "paperplane", "terminal"]),
  ]

  static func matchingGroups(query: String, selectedSymbol: String) -> [Group] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let presets = Set(groups.flatMap(\.symbols))
    let filtered = groups.compactMap { group -> Group? in
      let symbols = query.isEmpty
        ? group.symbols
        : group.symbols.filter { $0.localizedStandardContains(query) }
      return symbols.isEmpty ? nil : Group(id: group.id, title: group.title, symbols: symbols)
    }
    let custom = query.isEmpty ? selectedSymbol : query
    guard !custom.isEmpty, !presets.contains(custom), ScriptPresentation.isAvailableSymbol(custom) else {
      return filtered
    }
    return filtered + [Group(id: "custom", title: "Custom", symbols: [custom])]
  }
}

private struct ScriptIconPicker: View {
  let selectedSymbol: String
  let canChooseNone: Bool
  let onSelect: (String) -> Void
  @State private var query = ""

  private let columns = [GridItem(.adaptive(minimum: 40), spacing: 8)]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Search or enter symbol name", text: $query)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Search or enter symbol name")

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Button {
            onSelect("")
          } label: {
            Label("None", systemImage: "slash.circle")
          }
          .buttonStyle(.bordered)
          .tint(selectedSymbol.isEmpty ? .accentColor : .secondary)
          .disabled(!canChooseNone)
          .accessibilityAddTraits(selectedSymbol.isEmpty ? [.isSelected] : [])

          if !canChooseNone {
            Text("Enter a display name before choosing None.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          let groups = ScriptSymbolPresets.matchingGroups(query: query, selectedSymbol: selectedSymbol)
          if groups.isEmpty {
            Text("No matching or available icons.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          ForEach(groups, id: \.id) { group in
            ScriptIconGroup(group: group, selectedSymbol: selectedSymbol, columns: columns, onSelect: onSelect)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(16)
    .frame(width: 340, height: 390)
    .onAppear { query = "" }
  }
}

private struct ScriptIconGroup: View {
  let group: ScriptSymbolPresets.Group
  let selectedSymbol: String
  let columns: [GridItem]
  let onSelect: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(group.title)
        .font(.headline)
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(group.symbols, id: \.self) { symbol in
          Button {
            onSelect(symbol)
          } label: {
            Image(systemName: symbol)
              .frame(maxWidth: .infinity)
              .frame(height: 36)
              .background(selectedSymbol == symbol ? Color.accentColor.opacity(0.18) : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .help(symbol)
          .accessibilityLabel(symbol)
          .accessibilityAddTraits(selectedSymbol == symbol ? [.isSelected] : [])
        }
      }
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
    .frame(width: 500, height: 480)
}

#Preview("Empty") {
  @Previewable @State var script = Script(name: "", scriptPath: "")
  ScriptEditView(script: $script)
    .frame(width: 500, height: 480)
}

#Preview("Requires Prompt") {
  @Previewable @State var script = Script(
    name: "AI Rewrite",
    scriptPath: "ai-rewrite.sh",
    requiresPrompt: true
  )
  ScriptEditView(script: $script)
    .frame(width: 500, height: 480)
}

#Preview("Built-in Default") {
  @Previewable @State var script = Script(
    id: UUID(),
    builtin: BuiltinScript(feature: .decreaseIndent, indentationWidth: .two)!
  )
  ScriptEditView(script: $script)
    .frame(width: 500, height: 480)
}

#Preview("Built-in Customized") {
  @Previewable @State var script = Script(
    id: UUID(),
    builtin: BuiltinScript(feature: .blockQuote)!,
    display: .init(name: "Quote selection", symbolName: "star")
  )
  ScriptEditView(script: $script)
    .frame(width: 500, height: 480)
}

#Preview("Icon Picker") {
  ScriptIconPicker(selectedSymbol: "star", canChooseNone: true) { _ in }
}

#Preview("Long Display Name - Narrow") {
  @Previewable @State var script = Script(
    name: "A long display name that stays inside the editable field without widening the row",
    scriptPath: "'/usr/local/bin/format.sh'"
  )
  ScriptEditView(script: $script)
    .frame(width: 400, height: 480)
}
