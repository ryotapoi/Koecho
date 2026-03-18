import KoechoCore

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
