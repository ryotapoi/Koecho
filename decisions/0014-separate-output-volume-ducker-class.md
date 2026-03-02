# ADR 0014: Separate OutputVolumeDucker class for volume ducking

## Status

Accepted

## Context

SpeechAnalyzer mode does not benefit from macOS's automatic volume ducking (which only applies to System Dictation). To improve voice input experience, we need to lower the system output volume while the input panel is visible and restore it when the panel closes.

AudioDeviceManager (728 lines) already handles input device enumeration, volume control, and level metering via AUHAL. The output volume ducking feature uses the same CoreAudio APIs (AudioObjectGetPropertyData / SetPropertyData / listener blocks) but operates on output devices with different scope (kAudioObjectPropertyScopeOutput vs kAudioObjectPropertyScopeInput).

## Considered Options

- **A: Add output volume ducking to AudioDeviceManager** — Reuse existing CoreAudio helpers by adding a `scope` parameter. Fewer lines of code overall, but increases class responsibility and couples input device management with output volume ducking lifecycle.
- **B: Extract shared CoreAudio helpers into a utility module** — Create a CoreAudioHelper with scope-parameterized functions. Both classes call into the shared helpers. Reduces duplication but introduces a third module and tight coupling between two unrelated features.
- **C: Create a separate OutputVolumeDucker class** — Duplicate the structural CoreAudio patterns (property address setup, HasProperty/IsPropertySettable checks, listener block management) with output scope. Accept ~60 lines of structural duplication in exchange for complete independence.

## Decision

We will create a separate `OutputVolumeDucker` class (Option C) with its own CoreAudio helpers scoped to output devices.

## Consequences

- **Positive**: OutputVolumeDucker and AudioDeviceManager can evolve independently. Each class has a single, clear responsibility. Removing or modifying one does not affect the other.
- **Positive**: The ducking lifecycle (duck on panel show, restore on panel hide) is cleanly encapsulated behind a `VolumeDucking` protocol, enabling easy testing via MockVolumeDucker.
- **Negative**: ~60 lines of structural duplication between the two classes (property address setup, element fallback logic, listener block management patterns). If a CoreAudio API pattern needs fixing, both classes must be updated.
- **Neutral**: If a third CoreAudio feature is added in the future, extracting shared helpers may become worthwhile. For two classes, the duplication cost is acceptable.
