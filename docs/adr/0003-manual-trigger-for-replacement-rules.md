# ADR 0003: Manual trigger for replacement rules

## Status

Accepted

## Context

Replacement rules were initially designed to apply automatically in real-time as the user dictates. However, macOS Dictation holds uncommitted text in an internal marked text buffer (NSTextInputClient) and does not update `NSTextView.string` or `textStorage` until the text is committed. This means:

- `NSText.didChangeNotification` does not fire during Dictation
- `NSTextStorage.didProcessEditingNotification` does not fire during Dictation
- Polling `NSTextView.string` shows stale text (marked text not reflected)
- SwiftUI `.onChange(of:)` on the binding does not trigger

All attempted detection methods failed during active Dictation input.

## Considered Options

- **Real-time auto-replacement via NSTextView subclass**: Override `setMarkedText`/`insertText`/`unmarkText` to hook text commit events. Technically sound but requires replacing SwiftUI's internal NSTextView, adding significant complexity.
- **Polling + debounce**: Poll `NSTextView.string` at intervals and apply rules after a delay. Implemented and tested, but Dictation's marked text means polling reads stale values. The debounce infrastructure added complexity without delivering the intended UX.
- **Manual trigger + confirm-time application**: Remove all real-time infrastructure. Apply rules on explicit user action (Ctrl+R shortcut or Replace button) and automatically at confirm time before pasting. Simple, predictable, and works regardless of Dictation state.

## Decision

We will use manual trigger + confirm-time application for replacement rules. All real-time auto-replacement infrastructure (polling, debounce, text change detection) is removed. Rules are applied via Ctrl+R shortcut, a Replace button in the input panel, and automatically when the user confirms (before pasting).

## Consequences

- Positive: Simpler codebase with no polling/debounce Tasks. Predictable behavior regardless of input method. No risk of interfering with Dictation's marked text state.
- Positive: `hasMarkedText()` guard on the manual trigger prevents text corruption if the user presses Ctrl+R during active Dictation.
- Negative: Users must explicitly trigger replacement or wait until confirm. No visual feedback of replacements during typing.
- Neutral: The NSTextView subclass approach remains a viable future option if real-time replacement is desired (documented in knowledge.md).
- Neutral: Confirm-time application can be toggled off via `appliesReplacementRulesOnConfirm` setting (default: ON).
- Neutral: The shortcut key is customizable via `replacementShortcutKey` setting (default: "r", nil to disable).
