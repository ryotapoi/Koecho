import Testing
@testable import KoechoCore

@MainActor
struct ModifierTapDetectorTests {
    let fnKeyCode = UInt16(63)

    // MARK: - Single Tap (adapted from Bool → TapResult)

    @Test func tapQuickRelease() {
        var detector = ModifierTapDetector()

        let press = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        #expect(press == .none)

        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.2)
        // Goes to waitingForSecondTap, not singleTap yet
        #expect(release == .none)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.2))

        // Expire to get singleTap
        let expire = detector.expireDoubleTapWindow()
        #expect(expire == .singleTap)
    }

    @Test func longPressDoesNotFire() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.5)
        #expect(release == .none)
        #expect(detector.state == .idle)
    }

    @Test func keyDownCancelsTap() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        detector.handleKeyDown()
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release == .none)
    }

    @Test func otherModifierKeyDoesNotFire() {
        var detector = ModifierTapDetector()
        let commandKeyCode: UInt16 = 55

        let press = detector.handleFlagsChanged(keyCode: commandKeyCode, targetFlagIsSet: false, now: 1.0)
        #expect(press == .none)

        let release = detector.handleFlagsChanged(keyCode: commandKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release == .none)
    }

    @Test func otherModifierDuringWaitCancels() {
        var detector = ModifierTapDetector()
        let shiftKeyCode: UInt16 = 56

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: shiftKeyCode, targetFlagIsSet: true, now: 1.1)
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.15)
        #expect(release == .none)
    }

    @Test func releaseWithoutPressDoesNotFire() {
        var detector = ModifierTapDetector()

        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.0)
        #expect(release == .none)
    }

    @Test func consecutiveSingleTapsBothFire() {
        var detector = ModifierTapDetector()

        // First tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        let expire1 = detector.expireDoubleTapWindow()
        #expect(expire1 == .singleTap)

        // Second tap (interval > doubleTapInterval from first tap time, since we expired)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.5)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.6)
        let expire2 = detector.expireDoubleTapWindow()
        #expect(expire2 == .singleTap)
    }

    @Test func exactMaxHoldDurationDoesNotFire() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 0.0)
        // elapsed == maxHoldDuration (0.4s), should NOT fire because condition is `<`
        let release = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 0.4)
        #expect(release == .none)
        #expect(detector.state == .idle)
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
        #expect(release == .none)
    }

    @Test func duplicatePressIsIgnored() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        #expect(detector.state == .waitingForRelease(pressTime: 1.0))

        // Duplicate press — stays in waitingForRelease
        let dup = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.01)
        #expect(dup == .none)
        #expect(detector.state == .waitingForRelease(pressTime: 1.0))
    }

    @Test func duplicatePressStillFiresOnRelease() {
        var detector = ModifierTapDetector()

        // press (global) → press (local) → release (global) → release (local)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)

        let release1 = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release1 == .none)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))

        // Second release in waitingForSecondTap — should be ignored (delayed release)
        let release2 = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(release2 == .none)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))
    }

    // MARK: - Double Tap

    @Test func doubleTapDetected() {
        var detector = ModifierTapDetector()

        // First tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))

        // Second tap within doubleTapInterval
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.2)
        #expect(detector.state == .waitingForSecondRelease(firstTapTime: 1.1, pressTime: 1.2))

        let result = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.25)
        #expect(result == .doubleTap)
        #expect(detector.state == .idle)
    }

    @Test func expireDoubleTapWindowReturnsSingleTap() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))

        let result = detector.expireDoubleTapWindow()
        #expect(result == .singleTap)
        #expect(detector.state == .idle)
    }

    @Test func expireInIdleReturnsNone() {
        var detector = ModifierTapDetector()

        let result = detector.expireDoubleTapWindow()
        #expect(result == .none)
        #expect(detector.state == .idle)
    }

    @Test func secondPressToSlowStartsNewSingleTap() {
        var detector = ModifierTapDetector()

        // First tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))

        // Second press after doubleTapInterval
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.5)
        #expect(detector.state == .waitingForRelease(pressTime: 1.5))
    }

    @Test func secondReleaseToSlowFailsDoubleTap() {
        var detector = ModifierTapDetector()

        // First tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)

        // Second press
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.2)
        #expect(detector.state == .waitingForSecondRelease(firstTapTime: 1.1, pressTime: 1.2))

        // Release after maxHold
        let result = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.7)
        #expect(result == .none)
        #expect(detector.state == .idle)
    }

    @Test func keyDownDuringWaitingForSecondTapCancels() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))

        detector.handleKeyDown()
        #expect(detector.state == .idle)
    }

    @Test func otherModifierDuringWaitingForSecondTapCancels() {
        var detector = ModifierTapDetector()
        let shiftKeyCode: UInt16 = 56

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)

        let result = detector.handleFlagsChanged(keyCode: shiftKeyCode, targetFlagIsSet: true, now: 1.15)
        #expect(result == .none)
        #expect(detector.state == .idle)
    }

    @Test func duplicatePressInWaitingForSecondRelease() {
        var detector = ModifierTapDetector()

        // First tap
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)

        // Second press (global)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.2)

        // Duplicate second press (local) — should be ignored
        let dup = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.2)
        #expect(dup == .none)
        #expect(detector.state == .waitingForSecondRelease(firstTapTime: 1.1, pressTime: 1.2))

        // Release should still yield doubleTap
        let result = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.25)
        #expect(result == .doubleTap)
    }

    @Test func delayedReleaseInWaitingForSecondTapIgnored() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))

        // Delayed release from first tap (global/local overlap)
        let result = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.11)
        #expect(result == .none)
        #expect(detector.state == .waitingForSecondTap(firstTapTime: 1.1))
    }

    @Test func maxHoldExceededInWaitingForSecondRelease() {
        var detector = ModifierTapDetector()

        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.2)

        // Release after maxHold
        let result = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.65)
        #expect(result == .none)
        #expect(detector.state == .idle)
    }

    @Test func consecutiveSingleTapsWithLargeInterval() {
        var detector = ModifierTapDetector()

        // First tap → expire
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 1.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 1.1)
        let expire1 = detector.expireDoubleTapWindow()
        #expect(expire1 == .singleTap)

        // Second tap much later → expire
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: true, now: 2.0)
        _ = detector.handleFlagsChanged(keyCode: fnKeyCode, targetFlagIsSet: false, now: 2.1)
        let expire2 = detector.expireDoubleTapWindow()
        #expect(expire2 == .singleTap)
    }
}
