import SwiftUI

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

struct HotkeyKeyChoice: Hashable {
    let modifierKey: ModifierKey
    let side: ModifierSide

    var displayName: String {
        switch modifierKey {
        case .fn: "Fn (Globe)"
        default: "\(modifierKey.displayName) (\(side.displayName))"
        }
    }

    static let allChoices: [HotkeyKeyChoice] = {
        var choices: [HotkeyKeyChoice] = []
        for key in ModifierKey.allCases {
            if key == .fn {
                choices.append(HotkeyKeyChoice(modifierKey: .fn, side: .left))
            } else {
                choices.append(HotkeyKeyChoice(modifierKey: key, side: .left))
                choices.append(HotkeyKeyChoice(modifierKey: key, side: .right))
            }
        }
        return choices
    }()
}

extension ModifierKey {
    var displayName: String {
        switch self {
        case .command: "Command"
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        case .fn: "Fn (Globe)"
        }
    }
}

extension ModifierSide {
    var displayName: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

extension TapMode {
    var displayName: String {
        switch self {
        case .singleToggle: "Single Tap (toggle show/confirm)"
        case .doubleTapToShow: "Double Tap to show, Single Tap to confirm"
        }
    }
}
