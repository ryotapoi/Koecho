# ADR 0011: Immediate auto-replacement via DictationTextView

## Status

Accepted (supersedes ADR 0003)

## Context

ADR 0003 chose manual-only replacement triggers because macOS Dictation holds text in a marked text buffer invisible to `NSTextView.string`. Real-time detection was impossible at the time.

ADR 0010 introduced DictationTextView, an NSTextView subclass whose `didChangeText()` fires reliably on every text mutation — including when Dictation commits marked text. This made auto-replacement feasible.

The confirm-time application (`appliesReplacementRulesOnConfirm`) had a UX problem: users could not see the replacement result before pasting. Auto-replacement while the panel is open solves this.

Initially a debounced approach (configurable delay timer) was implemented, but `hasMarkedText()` guard already prevents replacement during active Dictation. The debounce added unnecessary latency without benefit — replacement should apply immediately once Dictation commits text.

## Considered Options

- **Keep manual-only (ADR 0003 status quo)**: No risk of interfering with Dictation, but poor discoverability and UX — many users never find the Ctrl+R shortcut.
- **Debounced auto-replacement**: Hook `didChangeText()`, start a delay timer, apply rules after the delay. Originally implemented but removed — `hasMarkedText()` guard makes the delay unnecessary.
- **Immediate auto-replacement with hasMarkedText guard**: Hook `didChangeText()` and call `applyOrPreviewReplacementRules()` directly. During Dictation (`hasMarkedText() = true`), show underline previews without modifying text. When Dictation commits (`hasMarkedText() = false`), apply replacements immediately.

## Decision

We will use immediate auto-replacement triggered by `didChangeText()`. On each text change, `applyOrPreviewReplacementRules()` checks `hasMarkedText()`: if true, it shows underline previews with hover tooltips without modifying text; if false, it applies replacements directly via `applyReplacementRulesNow()`.

Adding subviews to NSTextView during Dictation corrupts the marked text state and causes duplicate text. Previews are drawn using `draw(_:)` override (underlines) and a separate floating NSWindow (tooltips on hover).

Confirm always applies replacement rules before pasting, ensuring Dictation text is processed even when in-place replacement was impossible. Manual triggers (shortcut key, Replace button) follow the same hasMarkedText branch logic.

## Consequences

- Positive: Replacement results are visible immediately after Dictation commits, improving user confidence.
- Positive: During active Dictation (hasMarkedText() = true), replacement previews are shown as underlines with hover tooltips without modifying the text view.
- Positive: No delay configuration needed — simpler settings UI.
- Neutral: Confirm always applies replacement rules before pasting, regardless of whether Dictation was active. This reintroduces the "emptied text treated as cancel" edge case but is necessary because Dictation prevents in-place text modification.
- Neutral: `isSuppressingCallbacks` flag prevents feedback loops when `applyReplacementRulesNow()` updates the text view.
- Neutral: The shortcut key remains customizable via `replacementShortcutKey` setting.
- Negative: Preview underlines may flicker during rapid Dictation hypothesis updates (cleared and redrawn on each change). Acceptable tradeoff since text is still evolving.
