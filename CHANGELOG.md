# Changelog

All notable changes to Koecho are documented here. Release notes are reconstructed from GitHub Releases and version tags. See [CHANGELOG.ja.md](CHANGELOG.ja.md) for Japanese.

Release artifacts are available on [GitHub Releases](https://github.com/ryotapoi/Koecho/releases).

## Unreleased

### Internal

- Removed timing-dependent waits from dictation, hotkey, script, input-panel, and voice-input tests.
- Reported unavailable Speech Analyzer tests as disabled instead of silently passing empty test bodies.
- Isolated shared audio-input and speech-model verification state between tests.
- Centralized finalized and in-progress voice-input text editing and input-state writes under clear ownership.
- Extracted and tested replacement-preview tooltip presentation.
- Removed unused voice-input delegate forwarding from the input-panel controller.

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
