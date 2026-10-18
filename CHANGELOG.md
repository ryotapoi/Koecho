# Changelog

All notable changes to Koecho are documented here. See [CHANGELOG.ja.md](CHANGELOG.ja.md) for Japanese.

Release artifacts are available on [GitHub Releases](https://github.com/ryotapoi/Koecho/releases).

## 2.0.0 — 2026-10-19

### Compatibility

- Requires macOS 27.0 or later. Version 1.8.0 is the last release supporting macOS 14 and later.
- Uses on-device SpeechAnalyzer recognition exclusively; the system dictation input mode has been removed.

### What's New

- Preview replacement candidates at the caret and apply individual occurrences or candidates fully contained in the selection. A separate action replaces the whole document. Automatic replacement is off by default; saved preferences are preserved.
- Default panel shortcuts are Command+R for local replacement, Command+Shift+R for whole-document replacement, and Control+V for toggling voice input. Existing saved shortcuts, including unassigned shortcuts, are preserved.
- Undo the most recent successful manual script operation in one step, and copy the last panel content from the menu even after cancellation or a failed paste.
- Customize script display names and icons, add built-in operations from the add menu, and see the selected auto-run script in the panel.
- Reorganized audio, history, replacement, and script settings, improved Japanese translations, and removed the app icon selector.
- The panel supports smaller windows and starts at 480 × 240 pt when no saved frame exists.
- Added a voice transcription correction example using Apple Foundation Models via macOS 27's `fm` command.

### Bug Fixes

- Improved speech finalization, repeated phrases, caret preservation, and automatic scrolling to newly dictated text. Voice input pauses while custom scripts run.
- Fixed recognition startup and cancellation races, language switching, and microphone level monitoring after recognition or device reconnection. A notice appears when the selected microphone falls back to the system default.
- Protected IME composition and Unicode boundaries during replacement, and avoided Japanese IME conflicts in the default replacement shortcuts.
- Fixed IME candidates remaining after confirmation and old text returning when the panel reopened.
- Fixed a crash when deleting the last script.
- When automatic replacement is off, confirming input or adding a rule no longer applies pending replacements. Auto-run scripts and pasting receive the text with those candidates unchanged.
- Prevented duplicate confirmation while speech is finalizing, preserved paste targets for retries, and stopped clipboard restoration from overwriting newly copied content.
- Made script timeouts cover output collection, handled early stdin closure, and stopped active scripts when the panel is cancelled.
- Protected unreadable settings and history from unintended overwrites, and preserved history when clearing it cannot be saved.
- Removed recognized speech text from diagnostic logs.

### Internal

- Strengthened regression coverage and isolated hosted test settings and history from regular app data.

## 1.8.0 — 2026-09-20

### Compatibility

- Verified build compatibility with Xcode 27, macOS SDK 27, and Swift compiler 6.4 while retaining support for macOS 14.0 and later.

### Internal

- Consolidated custom and built-in script state into a single model while preserving existing saved scripts and the JSON format.
- Enabled Xcode recommended nonlocalized-string analysis, dead-code stripping, and String Catalog symbol generation.
- Simplified built-in text operations, replacement handling, input-panel service boundaries, and their regression tests.

## 1.7.0 — 2026-07-16

### What's New

- Added built-in Decrease Indent, Increase Indent, and Block Quote operations for selected lines, with configurable indentation width and no external script setup required.
- Added script reordering directly from the input panel on macOS 27 or later.

### Bug Fixes

- Allowed paste retry after granting Accessibility permission without restarting Koecho, while preserving the committed text and original target application.

## 1.6.8 — 2026-07-15

### Distribution

- Signed release artifacts with Developer ID and notarized them with Apple for standard Gatekeeper verification.

### Internal

- Added regression coverage and stronger assertions for output-volume device changes and CoreAudio-dependent components.
- Centralized Speech Analyzer session setup shared by recognition start and transcriber restart.
- Centralized VoiceInputMode defaults and semantic state checks.
- Removed timing-dependent waits from dictation, hotkey, script, input-panel, and voice-input tests.
- Reported unavailable Speech Analyzer tests as disabled instead of silently passing empty test bodies.
- Isolated shared audio-input and speech-model verification state between tests.
- Centralized finalized and in-progress voice-input text editing and input-state writes under clear ownership.
- Extracted and tested replacement-preview tooltip presentation.
- Removed unused voice-input delegate forwarding from the input-panel controller.
- Shared the replacement engine between preview and actual application paths.
- Centralized replacement-shortcut defaults and optional shortcut persistence.
- Removed legacy singular-pattern decoding for replacement rules.
- Named the HistoryStore data directory and documented its migration constraint.
- Extracted and tested shortcut-recorder key event decisions independently of AppKit events.
- Aligned replacement-rule decision records with the implemented confirmation behavior.
- Documented replacement rules at product-scope and detailed-behavior levels.

## 1.6.3 — 2026-07-05

- Improved replacement-rule editing when adding or removing multiple patterns.
- Improved reliability around transcription restarts and audio input handling.
- Added regression coverage for dictation startup, duplicate stripping, and display messages.
- Improved performance for derived settings lists.

## 1.6.2 — 2026-07-04

- Added transcriber restart support.
- Extracted and tested audio-device selection and Speech Analyzer decision rules to improve voice-input reliability.
- Added reusable timeout and speech-model preparation helpers.

## 1.6.1 — 2026-07-04

- Improved audio input level monitoring and added focused tests.
- Moved speech locale modeling into KoechoCore.
- Improved performance by caching derived view collections.

## 1.6.0 — 2026-07-04

- Improved dictation startup handling.
- Added regression coverage for display mapping and duplicate voice-input text.
- Improved clipboard-pasting test isolation.

## 1.5.0 — 2026-06-25

- Refreshed the input panel design and spacing.
- Added app icon switching support.
- Improved script prompts, toolbar states, and dark-mode presentation.
- Updated the README screenshot.

## 1.4.2 — 2026-06-15

- Refresh menu languages after speech locale changes.

## 1.4.1 — 2026-06-11

### Internal

- Refactored input-panel and voice-input state handling, including shared teardown, confirmation phases, insertion-point ownership, replay suppression, locale correction, and speech-model caching.
- Expanded test coverage around the input panel and related platform behavior.

## 1.4.0 — 2026-03-27

### What's New

- **Multi-pattern replacement**: Register multiple source patterns in a single replacement rule (for example, `GitHブ` and `ギットHub` → `GitHub`).
- **Replacement rule UI redesign**: Separate UI for simple replacement and regex modes.

### Bug Fixes

- Fixed a CoreAudio IO thread crash during `restartTranscriber`.
- Fixed text duplication when moving the cursor immediately after voice input.

## 1.3.0 — 2026-03-22

- Added full Japanese localization through a String Catalog.
- Improved Settings window reliability when reopening it from the menu bar.
- Removed non-functional keyboard shortcut indicators from the menu bar.
- Shortened the “Replacement Rules” sidebar label to “Replacement” / “置換”.

## 1.2.0 — 2026-03-20

- **InputPanel toolbar redesign**: Consolidated script and replacement controls into a unified, compact toolbar with consistent button sizing.
- **History popover improvement**: Enlarged the “Show Full Text” popover for better readability without scrolling.
- **Accessibility**: Added text labels to icon-only buttons and changed `HistoryRow` to use a proper Button.

### Internal

- Migrated GCD (`DispatchQueue`, `DispatchWorkItem`) to Swift Concurrency (`Task`, `@MainActor`).
- Modernized legacy APIs.
- Split large views and extracted focused View structs.
- Refactored `InputPanelController` callback wiring.

## 1.1.0 — 2026-03-18

- Added a voice-input **Off** mode. The panel can now open without starting a voice engine for keyboard-only workflows, such as typing Japanese in terminal apps where inline input can be glitchy.

## 1.0.1 — 2026-03-17

- Improved internal code quality and testability across audio devices, script settings, accessibility, speech analysis, and selection handling.

## 1.0.0 — 2026-03-12

Initial release of a lightweight voice input app for macOS.

- Voice input and keyboard editing with real-time recognition.
- Built on macOS Dictation and the Speech framework (macOS 26+).
- Shell script integration for text processing.
- Sample scripts for Claude Code headless mode.
- Supports macOS 14.0 (Sonoma) or later.
