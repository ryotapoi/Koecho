# ADR 0007: Double-tap detection with pure state machine and external timer

## Status

Accepted

## Context

T5 (hotkey customization) introduces a double-tap mode where users can double-tap a modifier key to show the panel. This requires detecting both single and double taps on modifier keys.

The existing `ModifierTapDetector` is a pure state machine (no timers, no NSEvent dependency) that returns a boolean on each event. Adding double-tap detection requires a timeout: after the first tap, we must wait to see if a second tap follows within 300ms. If it doesn't, we treat it as a single tap.

Two approaches were considered for managing this timeout.

## Considered Options

- **Option A: Timer inside the detector**: `ModifierTapDetector` owns a `DispatchSourceTimer` and fires callbacks when single/double tap is detected. This makes the detector self-contained but introduces side effects, makes it harder to test (need to mock timers or use real delays), and couples it to GCD.

- **Option B: Pure state machine + external timer**: `ModifierTapDetector` remains a pure state machine that returns `TapResult` (.none, .singleTap, .doubleTap). It enters a `waitingForSecondTap` state after the first tap's release. `HotkeyService` checks the detector's state after each event and manages a `DispatchSourceTimer` on main queue. When the timer fires, it calls `expireDoubleTapWindow()` on the detector, which returns `.singleTap` if still waiting.

## Decision

We will use Option B: keep `ModifierTapDetector` as a pure state machine and manage the double-tap timer in `HotkeyService`.

Additionally, in `singleToggle` mode and when the panel is already visible in `doubleTapToShow` mode, `HotkeyService` immediately calls `expireDoubleTapWindow()` instead of starting a timer. This eliminates any perceptible delay for users who don't use double-tap mode.

## Consequences

- `ModifierTapDetector` remains fully testable with synchronous unit tests (no timers, no async). State transitions are verified by checking the `state` property directly.
- `HotkeyService` takes on the responsibility of timer lifecycle management, making it slightly more complex. Timer tests require `async` tests with `Task.sleep`.
- The `singleToggle` mode has zero added latency because the timer is never started — the detector enters `waitingForSecondTap` but is immediately expired by the service.
- Future tap patterns (triple-tap, long-press actions) can be added by extending the state machine without changing the timer management pattern.
- The `doubleTapInterval` (300ms) is a property on the detector, not on `HotkeyConfig`, keeping it out of user-facing settings for now while remaining easy to expose later if needed.
