import Foundation

public enum TapResult: Equatable, Sendable {
    case none, singleTap, doubleTap
}

/// Detects modifier key tap patterns (single tap and double tap).
///
/// Pure state machine — no NSEvent dependency, no timers, fully testable.
/// Feed `flagsChanged` and `keyDown` events; returns a `TapResult`.
/// The caller (HotkeyService) manages the double-tap timeout timer
/// and calls `expireDoubleTapWindow` when it fires.
public struct ModifierTapDetector: Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case waitingForRelease(pressTime: TimeInterval)
        case waitingForSecondTap(firstTapTime: TimeInterval)
        case waitingForSecondRelease(firstTapTime: TimeInterval, pressTime: TimeInterval)
    }

    public var state: State = .idle
    public var maxHoldDuration: TimeInterval = 0.4
    public var doubleTapInterval: TimeInterval = 0.3

    // kVK_Function = 63
    public var targetKeyCode: UInt16 = 63

    public init() {}

    /// Handle a flagsChanged event.
    /// - Parameters:
    ///   - keyCode: The keyCode from the event.
    ///   - targetFlagIsSet: Whether the target modifier flag is currently set.
    ///   - now: Event timestamp (system uptime).
    /// - Returns: A `TapResult` indicating what was detected.
    public mutating func handleFlagsChanged(
        keyCode: UInt16, targetFlagIsSet: Bool, now: TimeInterval
    ) -> TapResult {
        guard keyCode == targetKeyCode else {
            state = .idle
            return .none
        }

        switch state {
        case .idle:
            if targetFlagIsSet {
                state = .waitingForRelease(pressTime: now)
            }
            return .none

        case .waitingForRelease(let pressTime):
            if targetFlagIsSet {
                // Duplicate press (e.g. global + local monitor both fire) — ignore
                return .none
            }
            // Released
            let elapsed = now - pressTime
            if elapsed < maxHoldDuration {
                state = .waitingForSecondTap(firstTapTime: now)
                return .none
            } else {
                state = .idle
                return .none
            }

        case .waitingForSecondTap(let firstTapTime):
            if !targetFlagIsSet {
                // Delayed release from global/local monitor overlap — ignore
                return .none
            }
            // Second press
            if now - firstTapTime <= doubleTapInterval {
                state = .waitingForSecondRelease(firstTapTime: firstTapTime, pressTime: now)
            } else {
                // Too slow — start a new single tap attempt
                state = .waitingForRelease(pressTime: now)
            }
            return .none

        case .waitingForSecondRelease(_, let pressTime):
            if targetFlagIsSet {
                // Duplicate press (global + local) — ignore
                return .none
            }
            // Released
            let elapsed = now - pressTime
            if elapsed < maxHoldDuration {
                state = .idle
                return .doubleTap
            } else {
                // Held too long — double tap failed
                state = .idle
                return .none
            }
        }
    }

    /// Called by HotkeyService when the double-tap timer expires.
    /// If still waiting for second tap, returns `.singleTap`.
    public mutating func expireDoubleTapWindow() -> TapResult {
        if case .waitingForSecondTap = state {
            state = .idle
            return .singleTap
        }
        return .none
    }

    /// Handle a keyDown event. Any key press cancels pending tap detection.
    public mutating func handleKeyDown() {
        state = .idle
    }
}
