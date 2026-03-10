import AppKit
import Carbon.HIToolbox
import KoechoCore

extension HotkeyConfig {
    public var keyCode: UInt16 {
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

    public var modifierFlag: NSEvent.ModifierFlags {
        switch modifierKey {
        case .command:  .command
        case .shift:    .shift
        case .option:   .option
        case .control:  .control
        case .fn:       .function
        }
    }
}
