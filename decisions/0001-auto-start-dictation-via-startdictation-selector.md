# ADR 0001: Auto-start Dictation via startDictation: selector

## Status

Accepted

## Context

Koecho uses macOS standard Dictation for voice input. After displaying the InputPanel, the user must manually start Dictation (e.g., pressing Fn twice). For better UX, Dictation should start automatically when the panel opens.

The InputPanel uses `.nonactivatingPanel` style mask, which means `NSApp` remains inactive. This creates uncertainty about whether the responder chain will correctly route the action.

## Considered Options

- **`startDictation:` via responder chain**: Send the standard `startDictation:` action through `NSApp.sendAction` or directly to the NSTextView. Lightweight, uses existing macOS responder infrastructure.
- **`NSSpeechRecognizer` API**: Use the speech recognition API directly. Requires more code, manages its own audio session, and duplicates what macOS Dictation already provides.
- **AppleScript / `osascript`**: Simulate Dictation activation via system events. Fragile, depends on UI element names, and requires additional permissions.
- **Simulated Fn key press via CGEvent**: Programmatically press Fn twice to trigger Dictation. Unreliable across macOS versions and keyboard configurations.

## Decision

We will send the `startDictation:` selector via `NSApp.sendAction(_:to:from:)` with a fallback to `textView.perform(_:with:)` if the responder chain doesn't route the action (which may happen due to the non-activating panel style).

## Consequences

- Dictation starts automatically when the panel opens, improving UX for the primary voice input workflow.
- Keyboard-only users are unaffected — if Dictation is disabled in System Settings or the selector fails silently, text input works normally.
- The `startDictation:` selector is not part of a public API, so it could break in future macOS versions. However, it has been stable across macOS releases and is the standard responder action for Dictation.
- No additional permissions or entitlements are required beyond what Koecho already needs.
