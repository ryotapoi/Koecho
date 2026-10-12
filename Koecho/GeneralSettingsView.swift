import KoechoCore
import SwiftUI

struct GeneralSettingsView: View {
  @Bindable var voiceInput: VoiceInputSettings
  @Bindable var paste: PasteSettings
  @Bindable var volumeDucking: VolumeDuckingSettings
  let onSpeechLocalesChanged: @MainActor () async -> Void

  var body: some View {
    Form {
      VoiceInputSection(
        voiceInput: voiceInput,
        onSpeechLocalesChanged: onSpeechLocalesChanged
      )
      VolumeDuckingSection(volumeDucking: volumeDucking)
      Section("Clipboard") {
        TextField("Clipboard restore delay (sec)", value: $paste.pasteDelay, format: .number)
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
  voiceInput.isVoiceInputEnabled = true
  return GeneralSettingsView(
    voiceInput: voiceInput,
    paste: PasteSettings(defaults: defaults),
    volumeDucking: VolumeDuckingSettings(defaults: defaults),
    onSpeechLocalesChanged: {}
  )
  .frame(width: 500, height: 600)
}
