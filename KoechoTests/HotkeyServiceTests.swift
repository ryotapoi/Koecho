import AppKit
import Carbon.HIToolbox
import Testing
@testable import Koecho

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

    // MARK: - Single Toggle Mode

    @Test func singleToggleModeImmediateSingleTap() {
        var singleTapCount = 0
        let service = makeService(tapMode: .singleToggle, onSingleTap: { singleTapCount += 1 })

        // Press
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        #expect(singleTapCount == 0)

        // Release
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 1)
    }

    @Test func singleToggleModeNoDoubleTapCallback() {
        var doubleTapCount = 0
        let service = makeService(tapMode: .singleToggle, onDoubleTap: { doubleTapCount += 1 })

        // Quick double tap — in singleToggle mode, each tap fires singleTap immediately
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.2)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.25)

        #expect(doubleTapCount == 0)
    }

    // MARK: - Double Tap Mode

    @Test func doubleTapModeDoubleTapCallsOnDoubleTap() {
        var doubleTapCount = 0
        let service = makeService(
            tapMode: .doubleTapToShow,
            onDoubleTap: { doubleTapCount += 1 }
        )

        // First tap
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(doubleTapCount == 0)

        // Second tap within interval
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.2)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.25)
        #expect(doubleTapCount == 1)
    }

    @Test func doubleTapModePanelVisibleSingleTapImmediate() {
        var singleTapCount = 0
        let service = makeService(
            tapMode: .doubleTapToShow,
            isPanelVisible: { true },
            onSingleTap: { singleTapCount += 1 }
        )

        // Single tap while panel visible — should fire immediately (no delay)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func doubleTapModeTimerExpiresSingleTap() async throws {
        var singleTapCount = 0
        let service = makeService(
            tapMode: .doubleTapToShow,
            onSingleTap: { singleTapCount += 1 }
        )

        // Single tap — timer should start
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 0)

        // Wait for timer to fire (doubleTapInterval is 0.3s)
        try await Task.sleep(for: .milliseconds(500))
        #expect(singleTapCount == 1)
    }

    // MARK: - updateConfig

    @Test func updateConfigResetsState() {
        var singleTapCount = 0
        let service = makeService(
            tapMode: .doubleTapToShow,
            onSingleTap: { singleTapCount += 1 }
        )

        // Start a tap
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        // Timer should be started, detector in waitingForSecondTap

        // Update config — should reset state and cancel timer
        let newConfig = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
        service.updateConfig(newConfig)

        #expect(service.detector.state == .idle)
        #expect(singleTapCount == 0)  // Timer was cancelled, no singleTap fired
    }

    @Test func updateConfigChangesTargetKey() {
        var singleTapCount = 0
        let leftCommandKeyCode = UInt16(kVK_Command)
        let service = makeService(
            tapMode: .singleToggle,
            onSingleTap: { singleTapCount += 1 }
        )

        // Update to left command
        let newConfig = HotkeyConfig(modifierKey: .command, side: .left, tapMode: .singleToggle)
        service.updateConfig(newConfig)

        // Fn should no longer work
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)
        #expect(singleTapCount == 0)

        // Left command should work
        service.processEvent(type: .flagsChanged, keyCode: leftCommandKeyCode, flags: .command, timestamp: 2.0)
        service.processEvent(type: .flagsChanged, keyCode: leftCommandKeyCode, flags: [], timestamp: 2.1)
        #expect(singleTapCount == 1)
    }

    // MARK: - keyDown cancels timer

    @Test func keyDownCancelsDoubleTapTimer() async throws {
        var singleTapCount = 0
        let service = makeService(
            tapMode: .doubleTapToShow,
            onSingleTap: { singleTapCount += 1 }
        )

        // Single tap — timer starts
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: .function, timestamp: 1.0)
        service.processEvent(type: .flagsChanged, keyCode: fnKeyCode, flags: [], timestamp: 1.1)

        // keyDown cancels the timer
        service.processEvent(type: .keyDown, keyCode: 0, flags: [], timestamp: 1.15)

        // Wait past timer interval
        try await Task.sleep(for: .milliseconds(500))
        #expect(singleTapCount == 0)  // Timer was cancelled
    }
}
