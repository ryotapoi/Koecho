import KoechoCore
import KoechoPlatform
import SwiftUI

struct HotkeySettingsView: View {
  @Bindable var settings: HotkeySettings
  @Bindable var voiceInput: VoiceInputSettings
  @Bindable var replacement: ReplacementSettings
  @Bindable var script: ScriptSettings

  private var keySelection: Binding<HotkeyKeyChoice> {
    Binding(
      get: {
        HotkeyKeyChoice(
          modifierKey: settings.hotkeyConfig.modifierKey, side: settings.hotkeyConfig.side)
      },
      set: { choice in
        settings.hotkeyConfig.modifierKey = choice.modifierKey
        settings.hotkeyConfig.side = choice.side
      }
    )
  }

  var body: some View {
    Form {
      Section("Hotkey") {
        Picker("Modifier Key", selection: keySelection) {
          ForEach(HotkeyKeyChoice.allChoices, id: \.self) { choice in
            Text(choice.displayName).tag(choice)
          }
        }
        Picker("Tap Mode", selection: $settings.hotkeyConfig.tapMode) {
          ForEach(TapMode.allCases, id: \.self) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .pickerStyle(.radioGroup)
      }
      Section("Input panel shortcuts") {
        HStack {
          Text("Voice input shortcut")
          Spacer()
          ShortcutKeyRecorder(shortcutKey: $voiceInput.voiceInputShortcutKey)
            .frame(width: 120)
        }
        HStack {
          Text("Replacement shortcut")
          Spacer()
          ShortcutKeyRecorder(shortcutKey: $replacement.replacementShortcutKey)
            .frame(width: 120)
        }
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Auto-run cycle shortcut")
            Spacer()
            ShortcutKeyRecorder(shortcutKey: $script.autoRunShortcutKey)
              .frame(width: 120)
          }
          Text("Cycle through scripts to auto-run on confirm")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

// MARK: - Previews

#Preview("Default") {
  let defaults = UserDefaults(suiteName: "preview-hotkey-default")!
  HotkeySettingsView(
    settings: HotkeySettings(defaults: defaults),
    voiceInput: VoiceInputSettings(defaults: defaults),
    replacement: ReplacementSettings(defaults: defaults),
    script: ScriptSettings(defaults: defaults)
  )
  .frame(width: 500, height: 500)
}
