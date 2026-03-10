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
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        #expect(singleTapCount == 0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 1)
    }

    @Test func singleToggleModeNoDoubleTapCallback() {
        var doubleTapCount = 0
        let service = makeService(tapMode: .singleToggle, onDoubleTap: { doubleTapCount += 1 })
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.2)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.25)
        #expect(doubleTapCount == 0)
    }

    @Test func doubleTapModeDoubleTapCallsOnDoubleTap() {
        var doubleTapCount = 0
        let service = makeService(tapMode: .doubleTapToShow, onDoubleTap: { doubleTapCount += 1 })
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(doubleTapCount == 0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.2)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.25)
        #expect(doubleTapCount == 1)
    }

    @Test func doubleTapModePanelVisibleSingleTapImmediate() {
        var singleTapCount = 0
        let service = makeService(tapMode: .doubleTapToShow, isPanelVisible: { true }, onSingleTap: { singleTapCount += 1 })
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func doubleTapModeTimerExpiresSingleTap() async throws {
        var singleTapCount = 0
        let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 0)
        try await Task.sleep(for: .milliseconds(500))
        #expect(singleTapCount == 1)
    }

    @Test func updateConfigResetsState() {
        var singleTapCount = 0
        let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        let newConfig = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
        service.updateConfig(newConfig)
        #expect(service.detector.state == .idle)
        #expect(singleTapCount == 0)
    }

    @Test func updateConfigChangesTargetKey() {
        var singleTapCount = 0
        let leftCommandKeyCode = UInt16(kVK_Command)
        let service = makeService(tapMode: .singleToggle, onSingleTap: { singleTapCount += 1 })
        let newConfig = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
        service.updateConfig(newConfig)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 0)
        service.processEvent(type: .flagsChanged, keyCode: leftCommandKeyCode, flags: .command, timestamp: 2.0)
        service.processEvent(type: .flagsChanged, keyCode: leftCommandKeyCode, flags: [], timestamp: 2.1)
        #expect(singleTapCount == 1)
    }

    @Test func keyDownCancelsDoubleTapTimer() async throws {
        var singleTapCount = 0
        let service = makeService(tapMode: .doubleTapToShow, onSingleTap: { singleTapCount += 1 })
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        service.processEvent(type: .keyDown, keyCode: 0, flags: [], timestamp: 1.15)
        try await Task.sleep(for: .milliseconds(500))
        #expect(singleTapCount == 0)
    }
}
