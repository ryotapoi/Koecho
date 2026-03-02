# ADR 0005: Dictation auto-start robustness with flag-controlled startup

## Status

Accepted (revised from original becomeKey + retry approach)

## Context

Dictation auto-start after `showPanel()` relied on a fixed 0.3-second `DispatchQueue.main.asyncAfter` delay before sending `startDictation:` via `NSApp.sendAction`. On first panel display (especially after a rebuild), 0.3 seconds was sometimes insufficient because the window had not fully initialized. `sendAction` returned `true` (responder chain accepted it) but Dictation silently failed to start. Subsequent displays worked reliably because the window was already created.

The challenge: there is no API to detect whether Dictation actually started, and `sendAction` always returns `true` regardless of actual activation.

## Considered Options

- **Increase fixed delay**: Simple but penalizes all displays (including fast 2nd+ shows) with a longer wait. Does not adapt to varying initialization times.
- **`becomeKey()` callback + retry**: Use `NSPanel.becomeKey()` as the trigger, then retry `sendAction` with increasing delays. **Rejected after implementation testing**: `startDictation:` is a toggle action — re-sending while Dictation is active stops it, making retry counterproductive. Also, `becomeKey()` fires independently from `makeFirstResponder`, breaking the required `makeFirstResponder` → delay → `startDictation:` sequence and increasing silent failure rate.
- **Flag-controlled startup within `clearTextView()`**: Keep Dictation startup in the existing `clearTextView()` flow (after `makeFirstResponder`), controlled by a `shouldStartDictation` flag. Extract `startDictation()` as a method with `NSApp.sendAction` fallback. Use cancellable `DispatchWorkItem` for cleanup.

## Decision

We will keep the Dictation startup inside `clearTextView()`, sequenced after `makeFirstResponder`, with a 0.3-second delay. The startup is gated by a `shouldStartDictation` flag (set only in `showPanel()`) and uses a cancellable `DispatchWorkItem` for proper cleanup on `cancel()`/`confirm()`. The `startDictation()` method is extracted with a fallback to `textView.perform(selector)` for `.nonactivatingPanel` responder chain issues. No retry is performed.

## Consequences

- The sequential `makeFirstResponder` → 0.3s delay → `startDictation:` timing is preserved, which testing showed is critical for reliable Dictation startup.
- The `shouldStartDictation` flag prevents unintended Dictation restarts (e.g., on `confirm()` failure re-display).
- Cancellable `DispatchWorkItem` prevents stale `startDictation:` calls from firing after the panel is dismissed.
- The `NSApp.sendAction` → `textView.perform` fallback covers `.nonactivatingPanel` responder chain gaps.
- The first-display timing issue (B1) is partially mitigated but not fully solved — the fundamental limitation is that `startDictation:` provides no success feedback.
