import KoechoCore
import SwiftUI

struct GeneralSettingsView: View {
  @Bindable var voiceInput: VoiceInputSettings
  @Bindable var script: ScriptSettings
  @Bindable var replacement: ReplacementSettings
  @Bindable var history: HistorySettings
  @Bindable var paste: PasteSettings
  @Bindable var volumeDucking: VolumeDuckingSettings
  @Bindable var appIcon: AppIconSettings
  let onSpeechLocalesChanged: @MainActor () async -> Void

  var body: some View {
    Form {
      Section("App Icon") {
        Picker("App icon", selection: $appIcon.selectedAppIcon) {
          Text("Current").tag(AppIconVariant.current)
          Text("Legacy (v1.4.2)").tag(AppIconVariant.legacy)
        }
        .pickerStyle(.segmented)
      }
      VoiceInputSection(
        voiceInput: voiceInput,
        onSpeechLocalesChanged: onSpeechLocalesChanged
      )
      VolumeDuckingSection(volumeDucking: volumeDucking)
        .disabled(voiceInput.effectiveVoiceInputMode == .off)
      Section("Clipboard") {
        TextField("Clipboard restore delay (sec)", value: $paste.pasteDelay, format: .number)
      }
      Section("Scripts") {
        TextField("Timeout (sec)", value: $script.scriptTimeout, format: .number)
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
      Section("Replacement Rules") {
        Toggle("Auto-replace", isOn: $replacement.isAutoReplacementEnabled)
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Shortcut key")
            Spacer()
            ShortcutKeyRecorder(shortcutKey: $replacement.replacementShortcutKey)
              .frame(width: 120)
          }
          Text("Avoid shortcuts used by other apps or the system")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Section("History") {
        Toggle("Enable History", isOn: $history.isHistoryEnabled)
        TextField("Max entries", value: $history.historyMaxCount, format: .number)
        TextField("Retention days", value: $history.historyRetentionDays, format: .number)
      }
    }
    .formStyle(.grouped)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

// MARK: - Previews

#Preview("Default") {
  let defaults = UserDefaults(suiteName: "preview-general-default")!
  let voiceInput = VoiceInputSettings(defaults: defaults)
  voiceInput.voiceInputMode = .dictation
  return GeneralSettingsView(
    voiceInput: voiceInput,
    script: ScriptSettings(defaults: defaults),
    replacement: ReplacementSettings(defaults: defaults),
    history: HistorySettings(defaults: defaults),
    paste: PasteSettings(defaults: defaults),
    volumeDucking: VolumeDuckingSettings(defaults: defaults),
    appIcon: AppIconSettings(defaults: defaults),
    onSpeechLocalesChanged: {}
  )
  .frame(width: 500, height: 600)
}
