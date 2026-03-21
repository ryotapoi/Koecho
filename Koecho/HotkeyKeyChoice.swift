import Foundation
import KoechoCore

struct HotkeyKeyChoice: Hashable {
    let modifierKey: ModifierKey
    let side: ModifierSide

    var displayName: String {
        switch modifierKey {
        case .fn: modifierKey.displayName
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
        case .command: String(localized: "Command")
        case .shift: String(localized: "Shift")
        case .option: String(localized: "Option")
        case .control: String(localized: "Control")
        case .fn: String(localized: "Fn (Globe)")
        }
    }
}

extension ModifierSide {
    var displayName: String {
        switch self {
        case .left: String(localized: "Left")
        case .right: String(localized: "Right")
        }
    }
}

extension TapMode {
    var displayName: String {
        switch self {
        case .singleToggle: String(localized: "Single Tap (toggle show/confirm)")
        case .doubleTapToShow: String(localized: "Double Tap to show, Single Tap to confirm")
        }
    }
}
