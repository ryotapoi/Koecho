import AppKit
import Carbon.HIToolbox
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct HotkeyServiceTests {
  let fnKeyCode = UInt16(kVK_Function)

  private func makeService(
    tapMode: TapMode = .singleToggle,
    isPanelVisible: @escaping @MainActor () -> Bool = { false },
    onSingleTap: @escaping @MainActor () -> Void = {},
    onDoubleTap: @escaping @MainActor () -> Void = {}
  ) -> HotkeyService {
    let config = HotkeyConfig(modifierKey: .fn, side: .left, tapMode: tapMode)
    return HotkeyService(
      hotkeyConfig: config,
      isPanelVisible: isPanelVisible,
      onSingleTap: onSingleTap,
      onDoubleTap: onDoubleTap
    )
  }

  @Test func singleToggleModeImmediateSingleTap() {
    var singleTapCount = 0
    let service = makeService(tapMode: .singleToggle, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    #expect(singleTapCount == 0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    #expect(singleTapCount == 1)
  }

  @Test func singleToggleModeNoDoubleTapCallback() {
    var doubleTapCount = 0
    let service = makeService(tapMode: .singleToggle, onDoubleTap: { doubleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.2)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.25)
    #expect(doubleTapCount == 0)
  }

  @Test func doubleTapModeDoubleTapCallsOnDoubleTap() {
    var doubleTapCount = 0
    let service = makeService(tapMode: .doubleTapToShow, onDoubleTap: { doubleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    #expect(doubleTapCount == 0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.2)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.25)
    #expect(doubleTapCount == 1)
  }

  @Test func doubleTapModePanelVisibleSingleTapImmediate() {
    var singleTapCount = 0
    let service = makeService(
      tapMode: .doubleTapToShow, isPanelVisible: { true }, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    #expect(singleTapCount == 1)
  }

  @Test func doubleTapModeExpiryCallsSingleTap() {
    var singleTapCount = 0
    let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    #expect(singleTapCount == 0)
    service.expireDoubleTapWindow()
    #expect(singleTapCount == 1)
  }

  @Test(arguments: [false, true])
  func interruptedTapStartsNewTimer(completeDoubleTap: Bool) async throws {
    var singleTapCount = 0
    var doubleTapCount = 0
    let service = makeService(
      tapMode: .doubleTapToShow,
      onSingleTap: { singleTapCount += 1 }, onDoubleTap: { doubleTapCount += 1 })
    defer { service.stop() }
    let clock = ContinuousClock()
    let start = clock.now
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 0.95)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.0)
    try await clock.sleep(until: start + .milliseconds(50))
    service.processEvent(
      type: .flagsChanged, keyCode: UInt16(kVK_Shift), flags: .shift, timestamp: 1.05)
    try await clock.sleep(until: start + .milliseconds(100))
    service.processEvent(
      type: .flagsChanged, keyCode: UInt16(kVK_Shift), flags: [], timestamp: 1.1)
    try await clock.sleep(until: start + .milliseconds(150))
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.15)
    try await clock.sleep(until: start + .milliseconds(200))
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.2)
    try await clock.sleep(until: start + .milliseconds(350))
    // The interrupted timer's 300 ms deadline must not expire the new tap.
    #expect(singleTapCount == 0)
    #expect(service.detector.state == .waitingForSecondTap(firstTapTime: 1.2))
    if completeDoubleTap {
      service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.35)
      try await clock.sleep(until: start + .milliseconds(400))
      service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.4)
      #expect(doubleTapCount == 1)
    }
    try await clock.sleep(until: start + .milliseconds(650))
    #expect(singleTapCount == (completeDoubleTap ? 0 : 1))
    #expect(doubleTapCount == (completeDoubleTap ? 1 : 0))
  }

  @Test func duplicateReleaseDoesNotExtendTimer() async throws {
    var singleTapCount = 0
    let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    let clock = ContinuousClock()
    let start = clock.now
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    try await clock.sleep(until: start + .milliseconds(200))
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    try await clock.sleep(until: start + .milliseconds(400))
    #expect(singleTapCount == 1)
    #expect(service.detector.state == .idle)
  }

  @Test func updateConfigResetsState() {
    var singleTapCount = 0
    let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    let newConfig = HotkeyConfig(modifierKey: .fn, side: .left, tapMode: .doubleTapToShow)
    service.updateConfig(newConfig)
    service.expireDoubleTapWindow()
    #expect(singleTapCount == 0)
  }

  @Test func updateConfigChangesTargetKey() {
    var singleTapCount = 0
    let leftCommandKeyCode = UInt16(kVK_Command)
    let service = makeService(tapMode: .singleToggle, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    let newConfig = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
    service.updateConfig(newConfig)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    #expect(singleTapCount == 0)
    service.processEvent(
      type: .flagsChanged, keyCode: leftCommandKeyCode, flags: .command, timestamp: 2.0)
    service.processEvent(
      type: .flagsChanged, keyCode: leftCommandKeyCode, flags: [], timestamp: 2.1)
    #expect(singleTapCount == 1)
  }

  @Test func keyDownPreventsSingleTapOnExplicitExpiry() {
    var singleTapCount = 0
    let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
    defer { service.stop() }
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
    service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
    service.processEvent(type: .keyDown, keyCode: 0, flags: [], timestamp: 1.15)
    service.expireDoubleTapWindow()
    #expect(singleTapCount == 0)
  }
}
