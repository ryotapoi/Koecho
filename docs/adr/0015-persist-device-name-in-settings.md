# ADR 0015: Persist audio input device name in Settings

## Status

Accepted

## Context

When a selected audio input device (e.g. AirPods Pro) is disconnected, the Microphone Picker in GeneralSettingsView shows a blank selection. The device UID is persisted in Settings, so the device reappears on reconnection, but the blank state during disconnection is confusing.

To display the device name while disconnected, the name must be available even when the device is absent from the system's device list.

## Considered Options

- **Runtime cache in AudioDeviceManager**: A dictionary mapping UID to name, populated on device list changes. However, `AudioDeviceManager` is created as `@State` per View instance, so the cache is lost when the settings view is dismissed. Making it `static` survives view lifecycle but not app restart.
- **View `@State` only**: Same lifecycle problem as above.
- **Persist device name in UserDefaults (Settings)**: Add a single `audioInputDeviceName: String?` property alongside the existing `audioInputDeviceUID`. Survives view dismissal and app restart. Minimal addition (one property, one UserDefaults key).

## Decision

We will persist the audio input device name in Settings (UserDefaults) alongside the device UID. The name is updated when the user selects a connected device in the Picker, cleared when "System Default" is selected, and left unchanged when a disconnected device remains selected.

## Consequences

- Disconnected devices are displayed with their name + "(not connected)" instead of a blank Picker, improving UX
- Device name survives app restart with no additional infrastructure
- If a device is renamed at the OS level (rare), the persisted name stays stale until the user reselects the device in the Picker; this is acceptable given the extremely low frequency
- One additional UserDefaults key (`audioInputDeviceName`) is added to the Settings surface
