import Carbon.HIToolbox

/// Detects a single modifier key "tap" (press and quick release).
///
/// Pure state machine — no NSEvent dependency, fully testable.
/// Feed `flagsChanged` and `keyDown` events; returns `true` when a tap is detected.
struct ModifierTapDetector {
    enum State: Equatable {
        case idle
        case waitingForRelease(pressTime: TimeInterval)
    }

    var state: State = .idle
    var maxHoldDuration: TimeInterval = 0.4

    // Target key configuration (changeable for future hotkey settings UI)
    var targetKeyCode: UInt16 = UInt16(kVK_Function)  // 63

    /// Handle a flagsChanged event.
    /// - Parameters:
    ///   - keyCode: The keyCode from the event.
    ///   - targetFlagIsSet: Whether the target modifier flag is currently set.
    ///   - now: Event timestamp (system uptime).
    /// - Returns: `true` if a tap was detected (fire).
    mutating func handleFlagsChanged(
        keyCode: UInt16, targetFlagIsSet: Bool, now: TimeInterval
    ) -> Bool {
        guard keyCode == targetKeyCode else {
            // Other modifier key pressed — cancel any pending detection
            state = .idle
            return false
        }

        switch state {
        case .idle:
            if targetFlagIsSet {
                state = .waitingForRelease(pressTime: now)
            }
            return false

        case .waitingForRelease(let pressTime):
            if targetFlagIsSet {
                // Duplicate press (e.g. global + local monitor both fire) — ignore
                return false
            }
            // Released
            state = .idle
            let elapsed = now - pressTime
            return elapsed < maxHoldDuration
        }
    }

    /// Handle a keyDown event. Any key press cancels pending tap detection.
    mutating func handleKeyDown() {
        state = .idle
    }
}
