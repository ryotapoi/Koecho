# ADR 0008: NSView-based shortcut key recorder

## Status

Accepted

## Context

The shortcut key setting UI needed to change from a TextField-based input to a key recorder that captures modifier keys and a character key from an actual keystroke. SwiftUI's `onKeyPress` modifier does not provide direct access to `NSEvent.modifierFlags`, making it impossible to distinguish between modifier key combinations (e.g., Cmd+Shift+C vs Cmd+C). Additionally, the TextField-based approach allowed full-width characters to be entered, which are invalid as shortcut keys.

## Considered Options

- **NSViewRepresentable + custom NSView with performKeyEquivalent override**: Wrap a custom NSView that overrides `performKeyEquivalent` and `keyDown` to capture keystrokes with full modifier flag information
- **NSViewRepresentable + NSEvent.addLocalMonitorForEvents**: Use a local event monitor to intercept key events, but `performKeyEquivalent` in parent views (e.g., NavigationSplitView) can consume modifier+key combos before `keyDown` fires
- **SwiftUI onKeyPress**: Use SwiftUI's native key handling, but it lacks `NSEvent.ModifierFlags` access and cannot reliably detect modifier combinations
- **Custom NSTextField subclass**: Override `keyDown` in a text field subclass, but text fields have their own key handling that interferes with shortcut recording

## Decision

We will use NSViewRepresentable wrapping a custom NSView that overrides `performKeyEquivalent` and `keyDown` to capture key events during recording. `performKeyEquivalent` fires before `keyDown` in the event processing chain, ensuring modifier+key combos are captured before other views can consume them. The recorder validates that the keystroke has at least one of Ctrl/Cmd/Option (Shift alone is rejected) and that the character is printable ASCII (0x21-0x7E).

## Consequences

- Full access to `NSEvent.modifierFlags` and `charactersIgnoringModifiers` enables accurate shortcut recording
- The full-width character input bug is eliminated since `charactersIgnoringModifiers` returns ASCII characters
- The NSView requires manual drawing and state management (recording state, appearance updates) instead of SwiftUI declarative UI
- Using `performKeyEquivalent` override instead of a local event monitor avoids event interception issues with parent views and eliminates the need for monitor lifecycle management
