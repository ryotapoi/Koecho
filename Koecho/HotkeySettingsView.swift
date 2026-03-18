import SwiftUI
import KoechoCore
import KoechoPlatform

struct HotkeySettingsView: View {
    @Bindable var settings: HotkeySettings

    private var keySelection: Binding<HotkeyKeyChoice> {
        Binding(
            get: { HotkeyKeyChoice(modifierKey: settings.hotkeyConfig.modifierKey, side: settings.hotkeyConfig.side) },
            set: { choice in
                settings.hotkeyConfig.modifierKey = choice.modifierKey
                settings.hotkeyConfig.side = choice.side
            }
        )
    }

    var body: some View {
        Form {
            Section("Modifier Key") {
                Picker("Key", selection: keySelection) {
                    ForEach(HotkeyKeyChoice.allChoices, id: \.self) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
            }

            Section("Tap Mode") {
                Picker("Mode", selection: $settings.hotkeyConfig.tapMode) {
                    ForEach(TapMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
