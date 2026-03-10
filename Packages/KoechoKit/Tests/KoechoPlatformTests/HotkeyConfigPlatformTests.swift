import AppKit
import Carbon.HIToolbox
import KoechoCore
import Testing
@testable import KoechoPlatform

@MainActor
struct HotkeyConfigPlatformTests {
    // MARK: - keyCode Mapping

    @Test func leftCommandKeyCode() {
        let config = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_Command))
    }

    @Test func rightCommandKeyCode() {
        let config = HotkeyConfig(modifierKey: .command, side: .right, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_RightCommand))
    }

    @Test func leftShiftKeyCode() {
        let config = HotkeyConfig(modifierKey: .shift, side: .left, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_Shift))
    }

    @Test func rightShiftKeyCode() {
        let config = HotkeyConfig(modifierKey: .shift, side: .right, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_RightShift))
    }

    @Test func leftOptionKeyCode() {
        let config = HotkeyConfig(modifierKey: .option, side: .left, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_Option))
    }

    @Test func rightOptionKeyCode() {
        let config = HotkeyConfig(modifierKey: .option, side: .right, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_RightOption))
    }

    @Test func leftControlKeyCode() {
        let config = HotkeyConfig(modifierKey: .control, side: .left, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_Control))
    }

    @Test func rightControlKeyCode() {
        let config = HotkeyConfig(modifierKey: .control, side: .right, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_RightControl))
    }

    @Test func fnLeftKeyCode() {
        let config = HotkeyConfig(modifierKey: .fn, side: .left, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_Function))
    }

    @Test func fnRightKeyCodeSameAsLeft() {
        let config = HotkeyConfig(modifierKey: .fn, side: .right, tapMode: .singleToggle)
        #expect(config.keyCode == UInt16(kVK_Function))
    }

    // MARK: - modifierFlag Mapping

    @Test func commandModifierFlag() {
        let config = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
        #expect(config.modifierFlag == .command)
    }

    @Test func shiftModifierFlag() {
        let config = HotkeyConfig(modifierKey: .shift, side: .left, tapMode: .singleToggle)
        #expect(config.modifierFlag == .shift)
    }

    @Test func optionModifierFlag() {
        let config = HotkeyConfig(modifierKey: .option, side: .left, tapMode: .singleToggle)
        #expect(config.modifierFlag == .option)
    }

    @Test func controlModifierFlag() {
        let config = HotkeyConfig(modifierKey: .control, side: .left, tapMode: .singleToggle)
        #expect(config.modifierFlag == .control)
    }

    @Test func fnModifierFlag() {
        let config = HotkeyConfig(modifierKey: .fn, side: .left, tapMode: .singleToggle)
        #expect(config.modifierFlag == .function)
    }
}
