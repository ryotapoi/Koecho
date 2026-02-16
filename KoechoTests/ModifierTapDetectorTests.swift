import Carbon.HIToolbox
import Testing
@testable import Koecho

struct ModifierTapDetectorTests {
    let fnKeyCode = UInt16(kVK_Function)

    @Test func tapQuickRelease() {
        var detector = ModifierTapDetector()

        let press = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        #expect(press == false)

        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.2)
        #expect(release == true)
    }

    @Test func longPressDoesNotFire() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.5)
        #expect(release == false)
    }

    @Test func keyDownCancelsTap() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        detector.handleKeyDown()
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release == false)
    }

    @Test func otherModifierKeyDoesNotFire() {
        var detector = ModifierTapDetector()
        let commandKeyCode: UInt16 = 55

        let press = detector.handleFlagsChanged(keyCode: commandKeyCode, targetFlagIsSet: false, now: 1.0)
        #expect(press == false)

        let release = detector.handleFlagsChanged(keyCode: commandKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release == false)
    }

    @Test func otherModifierDuringWaitCancels() {
        var detector = ModifierTapDetector()
        let shiftKeyCode: UInt16 = 56

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: shiftKeyCode, targetFlagIsSet: true, now: 1.1)
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.15)
        #expect(release == false)
    }

    @Test func releaseWithoutPressDoesNotFire() {
        var detector = ModifierTapDetector()

        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.0)
        #expect(release == false)
    }

    @Test func consecutiveTapsBothFire() {
        var detector = ModifierTapDetector()

        // First tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        let release1 = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release1 == true)

        // Second tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.5)
        let release2 = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.6)
        #expect(release2 == true)
    }

    @Test func exactMaxHoldDurationDoesNotFire() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 0.0)
        // elapsed == maxHoldDuration (0.4s), should NOT fire because condition is `<`
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 0.4)
        #expect(release == false)
    }

    @Test func handleKeyDownInIdleIsNoop() {
        var detector = ModifierTapDetector()

        detector.handleKeyDown()
        #expect(detector.state == .idle)
    }

    @Test func handleKeyDownThenReleaseDoesNotFire() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        detector.handleKeyDown()
        #expect(detector.state == .idle)

        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release == false)
    }

    @Test func duplicatePressIsIgnored() {
        var detector = ModifierTapDetector()

        // First press
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        #expect(detector.state == .waitingForRelease(pressTime: 1.0))

        // Duplicate press (global + local monitor both fire) — stays in waitingForRelease
        let dup = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.01)
        #expect(dup == false)
        #expect(detector.state == .waitingForRelease(pressTime: 1.0))
    }

    @Test func duplicatePressStillFiresOnRelease() {
        var detector = ModifierTapDetector()

        // press (global) → press (local) → release (global) → release (local)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)

        let release1 = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release1 == true)

        // Second release should not fire again (already in idle)
        let release2 = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release2 == false)
    }
}
