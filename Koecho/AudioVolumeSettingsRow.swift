import KoechoCore
import SwiftUI

/// Shares an intrinsic label column across the three audio volume rows, even across sections.
struct AudioVolumeSettingsRow<Content: View>: View {
  let label: Text
  @ViewBuilder let content: Content

  var body: some View {
    AudioVolumeSettingsLayout {
      ZStack(alignment: .leading) {
        // Reserve the same localized label width without measuring or lifting meter state.
        ZStack {
          Text("Input volume")
          Text("Input Level")
          Text("Target volume")
        }
        .hidden()
        .accessibilityHidden(true)
        label
      }
      .fixedSize(horizontal: true, vertical: false)
      content
    }
  }
}

#Preview("Audio volume rows") {
  let defaults = UserDefaults(suiteName: "preview-audio-volume-rows")!
  let settings = VolumeDuckingSettings(defaults: defaults)
  settings.isVolumeDuckingEnabled = true
  return Form {
    Section("Voice Input") {
      AudioVolumeSettingsRow(label: Text("Input volume")) {
        Slider(value: .constant(0.6), in: 0...1) {
          Text("Input volume")
        }
        .labelsHidden()
      }
      InputLevelMeter(level: 0.6)
    }
    VolumeDuckingSection(volumeDucking: settings)
  }
  .formStyle(.grouped)
  .frame(width: 500, height: 300)
}
