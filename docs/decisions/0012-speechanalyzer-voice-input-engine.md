# ADR 0012: SpeechAnalyzer voice input engine

## Status

Accepted

## Context

Koecho relies on macOS system Dictation (`startDictation:` selector) for voice input. This approach has inherent limitations:

- **Unreliable auto-start** (Bug B1): Dictation silently fails when triggered immediately after panel display, requiring a 0.3s delay workaround that still isn't 100% reliable.
- **No programmatic control**: No API to detect success/failure, no way to retry (toggle behavior), and `hasMarkedText()` blocks text modifications during recognition.
- **No volatile text access**: Hypothesis text lives inside the input method's internal buffer and isn't visible to the app until confirmed.

macOS 26 introduces the SpeechAnalyzer framework within the Speech framework, providing a programmatic on-device speech recognition API with full control over the recognition lifecycle.

## Considered Options

- **Option A: Keep Dictation only** — No changes. Accept the B1 bug and marked text limitations.
- **Option B: SpeechRecognizer (SFSpeechRecognizer)** — Available since macOS 10.15. Requires network or on-device model. No dictation-optimized punctuation.
- **Option C: SpeechAnalyzer with DictationTranscriber** — macOS 26+ only. On-device, dictation-optimized with automatic punctuation. Volatile results available. Full lifecycle control via AVAudioEngine.
- **Option D: Replace Dictation entirely with SpeechAnalyzer** — Drop Dictation support. Requires macOS 26 as minimum deployment target.

## Decision

We will implement Option C: add SpeechAnalyzer as an alternative voice input engine behind a `VoiceInputEngine` protocol abstraction, while keeping Dictation as the default and only option on macOS 14–25.

Key design decisions:
- **VoiceInputEngine protocol** abstracts over `DictationEngine` and `SpeechAnalyzerEngine`, allowing the controller to be engine-agnostic.
- **DictationTranscriber** (not SpeechTranscriber) is used for automatic punctuation in dictation-style input.
- **Volatile text** is displayed inline in the text view using `NSLayoutManager.addTemporaryAttribute` (gray foreground + light background), not underlines (which conflict with replacement rule previews).
- **Keyboard + voice coexistence**: `voiceInsertionPoint` (UTF-16 offset) tracks where voice results are inserted, updated on cursor movement. Keyboard input clears volatile text via `shouldChangeText(in:replacementString:)`.
- **Engine selection** is a user setting (`Settings.voiceInputMode`), defaulting to Dictation. The setting UI only appears on macOS 26+.
- **Audio thread safety**: `AsyncStream.Continuation` is captured as a local variable in the audio tap closure to avoid `@MainActor` access from the audio thread.

## Consequences

**Positive:**
- Eliminates the B1 bug for SpeechAnalyzer mode (programmatic start, no toggle behavior)
- Enables keyboard + voice simultaneous input
- Provides volatile text preview during recognition
- On-device processing preserves privacy
- Protocol abstraction isolates engine-specific code, making future engine additions straightforward

**Negative:**
- SpeechAnalyzer is macOS 26+ only — users on macOS 14–25 remain on Dictation with its limitations
- Requires microphone permission (`NSMicrophoneUsageDescription`) even though Dictation mode doesn't need it
- First-time use may trigger a model download, adding latency
- Audio format conversion (AVAudioConverter) adds complexity for non-standard microphone configurations
- `@available(macOS 26, *)` annotations and runtime guards add code complexity
- Testing SpeechAnalyzer in CI requires macOS 26 runners; tests use runtime `guard #available` to skip on older OS

**Neutral:**
- DictationTextView/DictationTextEditor renamed to VoiceInputTextView/VoiceInputTextEditor to reflect the broader scope
- Existing Dictation behavior is unchanged (extracted into DictationEngine but functionally identical)
