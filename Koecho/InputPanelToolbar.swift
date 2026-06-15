import KoechoCore
import SwiftUI

struct InputPanelToolbar: View {
  let voiceInputMode: VoiceInputMode
  let replacementRules: [ReplacementRule]
  let scripts: [Script]
  @Bindable var scriptSettings: ScriptSettings
  let isRunningScript: Bool
  let hasPromptScript: Bool
  var onSwitchEngine: () async -> Void
  var onApplyReplacementRules: () -> Void
  var onExecuteScript: (Script) async -> Void
  var onConfirm: () async -> Void
  let replacementShortcutKey: ShortcutKey?

  private var hasAutoRunScripts: Bool {
    !scriptSettings.eligibleAutoRunScripts.isEmpty
  }

  var body: some View {
    HStack(spacing: 8) {
      Button {
        Task { await onSwitchEngine() }
      } label: {
        Label {
          Text("Voice")
        } icon: {
          Image("MenuBarIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
        }
      }
      .buttonStyle(.koechoToolbar(isEmphasized: voiceInputMode != .off))
      .disabled(isRunningScript || voiceInputMode == .off)
      .help(
        voiceInputMode == .off ? String(localized: "Voice input is off") : String(localized: "Voice")
      )

      if !replacementRules.isEmpty {
        Button {
          onApplyReplacementRules()
        } label: {
          Label("Replace", systemImage: "arrow.2.squarepath")
        }
        .buttonStyle(.koechoToolbar())
        .help(
          helpText(
            String(localized: "Apply replacement rules"), shortcut: replacementShortcutKey)
        )
        .disabled(isRunningScript)
      }

      ScrollView(.horizontal) {
        HStack(spacing: 6) {
          ForEach(scripts) { script in
            Button {
              Task { await onExecuteScript(script) }
            } label: {
              Text(script.name)
            }
            .buttonStyle(.koechoToolbar())
            .help(helpText(script.name, shortcut: script.shortcutKey))
            .disabled(isRunningScript || hasPromptScript)
          }
        }
        .padding(.vertical, 1)
      }
      .scrollIndicators(.hidden)

      Spacer(minLength: 8)

      autoRunMenu

      Button {
        Task { await onConfirm() }
      } label: {
        Label("Confirm", systemImage: "fn")
      }
      .buttonStyle(.koechoToolbar(isPrimary: true))
      .keyboardShortcut(.return, modifiers: .command)
      .disabled(isRunningScript)
    }
    .font(.caption)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.bar)
    .overlay(alignment: .top) {
      Divider()
    }
  }

  private func helpText(_ label: String, shortcut: ShortcutKey?) -> String {
    if let shortcut {
      "\(label) (\(shortcut.displayName))"
    } else {
      label
    }
  }

  @ViewBuilder
  private var autoRunMenu: some View {
    if hasAutoRunScripts {
      Menu {
        AutoRunScriptMenuContent(scriptSettings: scriptSettings)
      } label: {
        Label {
          Text(scriptSettings.autoRunScript?.name ?? String(localized: "None"))
        } icon: {
          Image(systemName: "bolt.fill")
        }
      }
      .menuStyle(.borderlessButton)
      .buttonStyle(.koechoToolbar())
      .fixedSize()
      .help(
        helpText(
          String(localized: "Cycle auto-run script selection"),
          shortcut: scriptSettings.autoRunShortcutKey)
      )
    } else {
      Button {
      } label: {
        Label {
          Text("None")
        } icon: {
          Image(systemName: "bolt.fill")
        }
      }
      .buttonStyle(.koechoToolbar())
      .disabled(true)
    }
  }
}

// MARK: - Previews

#Preview("Full") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-full")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  scriptSettings.scripts = [
    Script(name: "Format", scriptPath: "format.sh"),
    Script(name: "AI", scriptPath: "ai.sh"),
  ]
  return InputPanelToolbar(
    voiceInputMode: .dictation,
    replacementRules: [ReplacementRule(patterns: ["test"], replacement: "Test")],
    scripts: scriptSettings.scripts,
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
    onExecuteScript: { _ in },
    onConfirm: {},
    replacementShortcutKey: ShortcutKey(modifiers: [.control], character: "r")
  )
  .frame(width: 350, height: 40)
}

#Preview("Running Script") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-running")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  return InputPanelToolbar(
    voiceInputMode: .off,
    replacementRules: [],
    scripts: [Script(name: "Format", scriptPath: "format.sh")],
    scriptSettings: scriptSettings,
    isRunningScript: true,
    hasPromptScript: false,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
    onExecuteScript: { _ in },
    onConfirm: {},
    replacementShortcutKey: nil
  )
  .frame(width: 350, height: 40)
}

#Preview("Dark") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-dark")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  scriptSettings.scripts = [
    Script(name: "Format", scriptPath: "format.sh"),
    Script(name: "AI", scriptPath: "ai.sh"),
  ]
  return InputPanelToolbar(
    voiceInputMode: .dictation,
    replacementRules: [ReplacementRule(patterns: ["test"], replacement: "Test")],
    scripts: scriptSettings.scripts,
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
    onExecuteScript: { _ in },
    onConfirm: {},
    replacementShortcutKey: ShortcutKey(modifiers: [.control], character: "r")
  )
  .frame(width: 350, height: 40)
  .preferredColorScheme(.dark)
}
