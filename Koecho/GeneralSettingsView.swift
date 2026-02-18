import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: Settings

    private var replacementShortcutKeyBinding: Binding<String> {
        Binding(
            get: { settings.replacementShortcutKey ?? "" },
            set: { newValue in
                let trimmed = String(newValue.prefix(1)).lowercased()
                settings.replacementShortcutKey = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    var body: some View {
        Form {
            Section("Clipboard") {
                TextField("Clipboard restore delay (sec)", value: $settings.pasteDelay, format: .number)
            }
            Section("Scripts") {
                TextField("Timeout (sec)", value: $settings.scriptTimeout, format: .number)
            }
            Section("Replacement Rules") {
                Toggle("Apply on confirm", isOn: $settings.appliesReplacementRulesOnConfirm)
                HStack {
                    Text("Shortcut key")
                    Spacer()
                    TextField("Key", text: replacementShortcutKeyBinding)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
