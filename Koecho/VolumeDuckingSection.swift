import SwiftUI
import KoechoCore

struct VolumeDuckingSection: View {
    @Bindable var volumeDucking: VolumeDuckingSettings

    var body: some View {
        Section("Volume Ducking") {
            Toggle("Lower system volume while input panel is open", isOn: $volumeDucking.isVolumeDuckingEnabled)
            if volumeDucking.isVolumeDuckingEnabled {
                HStack {
                    Text("Target volume")
                    Slider(
                        value: $volumeDucking.volumeDuckingLevel,
                        in: 0...1
                    )
                    Text("\(Int(round(volumeDucking.volumeDuckingLevel * 100)))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                Text("System output volume will be lowered to this level (or kept as-is if already lower) while the input panel is visible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
