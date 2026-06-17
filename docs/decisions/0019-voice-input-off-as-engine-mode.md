# ADR 0019: Voice Input Off as Engine Mode

## Status

Accepted

## Context

Koecho v1.1 adds a "voice input off" mode for keyboard-only use. The initial plan introduced a separate `isVoiceInputEnabled: Bool` property alongside the existing `voiceInputMode` enum. This created two orthogonal states (enabled/disabled × engine type) and required coordinating them across Settings UI, menu bar, panel indicator, and runtime engine lifecycle.

During implementation, user feedback revealed several issues:
- Dictation mode cannot reliably support runtime toggle (startDictation: timing constraints)
- A separate boolean + menu + panel Enable button added UI complexity without clear value
- Users explicitly set voice off in Settings — no need for quick-toggle affordances

## Considered Options

- **Option A: Separate `isVoiceInputEnabled` boolean** — Toggle in Settings, Voice Input menu in menu bar, Enable button in panel. Requires runtime toggle coordination and Dictation-specific workarounds.
- **Option B: Add `.off` case to `VoiceInputMode` enum** — Engine selection becomes Off/Dictation/SpeechAnalyzer. Settings-only switching. No menu bar or panel toggle UI.
- **Option C: SpeechAnalyzer-only feature** — Only available when using SpeechAnalyzer engine. Simpler but excludes Dictation users.

## Decision

We will add `.off` as a case in `VoiceInputMode` and remove the separate `isVoiceInputEnabled` property. Voice input mode is selected exclusively in Settings (segmented picker on macOS 26+, toggle on older macOS). No menu bar Voice Input menu or panel Enable button.

## Consequences

- Simpler state model: one enum instead of two orthogonal properties
- Settings-only switching avoids Dictation runtime toggle issues entirely
- No accidental voice-off from menu interaction
- Legacy `isVoiceInputEnabled=false` migrated to `.off` automatically
- Runtime toggle (while panel is open) is not supported — change takes effect on next panel open
- Volume ducking section in Settings is disabled when voice is off, making the relationship visible
