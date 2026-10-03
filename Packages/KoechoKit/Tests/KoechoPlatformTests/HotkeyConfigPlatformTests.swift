import AppKit
import Carbon.HIToolbox
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct HotkeyConfigPlatformTests {
  @Test(arguments: [
    (ModifierKey.command, ModifierSide.left, UInt16(kVK_Command)),
    (.command, .right, UInt16(kVK_RightCommand)),
    (.shift, .left, UInt16(kVK_Shift)),
    (.shift, .right, UInt16(kVK_RightShift)),
    (.option, .left, UInt16(kVK_Option)),
    (.option, .right, UInt16(kVK_RightOption)),
    (.control, .left, UInt16(kVK_Control)),
    (.control, .right, UInt16(kVK_RightControl)),
    (.fn, .left, UInt16(kVK_Function)),
    (.fn, .right, UInt16(kVK_Function)),
  ])
  func keyCodeMapping(_ modifierKey: ModifierKey, _ side: ModifierSide, _ expected: UInt16) {
    let config = HotkeyConfig(modifierKey: modifierKey, side: side, tapMode: .singleToggle)
    #expect(config.keyCode == expected)
  }

  @Test(arguments: [
    (ModifierKey.command, NSEvent.ModifierFlags.command),
    (.shift, .shift),
    (.option, .option),
    (.control, .control),
    (.fn, .function),
  ])
  func modifierFlagMapping(_ modifierKey: ModifierKey, _ expected: NSEvent.ModifierFlags) {
    let config = HotkeyConfig(modifierKey: modifierKey, side: .left, tapMode: .singleToggle)
    #expect(config.modifierFlag == expected)
  }
}
