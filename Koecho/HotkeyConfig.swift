import AppKit
import Carbon.HIToolbox

enum ModifierKey: String, Codable, CaseIterable {
    case command, shift, option, control, fn
}

enum ModifierSide: String, Codable, CaseIterable {
    case left, right
}

enum TapMode: String, Codable, CaseIterable {
    case singleToggle, doubleTapToShow
}

struct HotkeyConfig: Codable, Equatable {
    var modifierKey: ModifierKey
    var side: ModifierSide
    var tapMode: TapMode

    static let `default` = HotkeyConfig(modifierKey: .fn, side: .left, tapMode: .singleToggle)

    var keyCode: UInt16 {
        switch (modifierKey, side) {
        case (.command, .left):  UInt16(kVK_Command)
        case (.command, .right): UInt16(kVK_RightCommand)
        case (.shift, .left):    UInt16(kVK_Shift)
        case (.shift, .right):   UInt16(kVK_RightShift)
        case (.option, .left):   UInt16(kVK_Option)
        case (.option, .right):  UInt16(kVK_RightOption)
        case (.control, .left):  UInt16(kVK_Control)
        case (.control, .right): UInt16(kVK_RightControl)
        case (.fn, _):           UInt16(kVK_Function)
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch modifierKey {
        case .command:  .command
        case .shift:    .shift
        case .option:   .option
        case .control:  .control
        case .fn:       .function
        }
    }
}
