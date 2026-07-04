import KoechoCore
import SwiftUI

struct InputPanelToolbar: View {
  let voiceInputMode: VoiceInputMode
  let replacementRules: [ReplacementRule]
  @Bindable var scriptSettings: ScriptSettings
  let isRunningScript: Bool
  let hasPromptScript: Bool
  let hotkeyConfig: HotkeyConfig
  var onSwitchEngine: () async -> Void
  var onApplyReplacementRules: () -> Void
  var onConfirm: () async -> Void
  let replacementShortcutKey: ShortcutKey?

  private var hasAutoRunScripts: Bool {
    !scriptSettings.eligibleAutoRunScripts.isEmpty
  }

  private var isVoiceEnabled: Bool {
    voiceInputMode != .off
  }

  var body: some View {
    HStack(spacing: 8) {
      Button {
        Task { await onSwitchEngine() }
      } label: {
        Label {
          Text("Voice")
        } icon: {
          Image(isVoiceEnabled ? "KoechoStatusItemColor" : "MenuBarIcon")
            .renderingMode(isVoiceEnabled ? .original : .template)
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
        }
      }
      .buttonStyle(.koechoToolbar(isEmphasized: isVoiceEnabled))
      .disabled(isRunningScript)
      .help(
        voiceInputMode == .off ? String(localized: "Voice input is off") : String(localized: "Voice")
      )

      if !replacementRules.isEmpty {
        Button {
          onApplyReplacementRules()
        } label: {
          Label("Replace", systemImage: "arrow.2.squarepath")
        }
        .buttonStyle(.koechoToolbar(isEmphasized: true))
        .help(
          helpText(
            String(localized: "Apply replacement rules"), shortcut: replacementShortcutKey)
        )
        .disabled(isRunningScript)
      }

      Spacer(minLength: 8)

      autoRunMenu

      Button {
        Task { await onConfirm() }
      } label: {
        HStack(spacing: 8) {
          Text(hotkeyConfig.modifierBadge)
            .font(.caption.bold())
          Text("Confirm")
            .font(.caption.bold())
        }
      }
      .accessibilityLabel(Text("Confirm"))
      .buttonStyle(.koechoToolbar(isPrimary: !hasPromptScript))
      .keyboardShortcut(.return, modifiers: .command)
      .disabled(isRunningScript)
    }
    .font(.caption)
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(.regularMaterial)
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
          Image(systemName: "wand.and.stars")
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
          Image(systemName: "wand.and.stars")
        }
      }
      .buttonStyle(.koechoToolbar())
      .disabled(true)
    }
  }
}

extension HotkeyConfig {
  var modifierBadge: String {
    switch modifierKey {
    case .command: "\u{2318}"
    case .shift: "\u{21E7}"
    case .option: "\u{2325}"
    case .control: "\u{2303}"
    case .fn: "fn"
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
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
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
    scriptSettings: scriptSettings,
    isRunningScript: true,
    hasPromptScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
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
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
    onConfirm: {},
    replacementShortcutKey: ShortcutKey(modifiers: [.control], character: "r")
  )
  .frame(width: 350, height: 40)
  .preferredColorScheme(.dark)
}

#Preview("Prompting") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-prompting")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  scriptSettings.scripts = [
    Script(name: "Format", scriptPath: "format.sh"),
    Script(name: "AI", scriptPath: "ai.sh"),
  ]
  return InputPanelToolbar(
    voiceInputMode: .dictation,
    replacementRules: [ReplacementRule(patterns: ["test"], replacement: "Test")],
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: true,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onApplyReplacementRules: {},
    onConfirm: {},
    replacementShortcutKey: ShortcutKey(modifiers: [.control], character: "r")
  )
  .frame(width: 350, height: 40)
  .opacity(0.45)
}
