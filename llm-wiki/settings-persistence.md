---
regen: compiled
sources:
  - Packages/KoechoKit/Sources/KoechoCore/Settings.swift
  - Packages/KoechoKit/Sources/KoechoCore/AppIconSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/HistorySettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/HotkeySettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/PasteSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/VolumeDuckingSettings.swift
  - Koecho/SettingsView.swift
  - Koecho/GeneralSettingsView.swift
  - Koecho/HotkeySettingsView.swift
  - Koecho/VoiceInputSection.swift
  - Koecho/ScriptManagementView.swift
  - Koecho/ReplacementRuleManagementView.swift
  - Packages/KoechoKit/Tests/KoechoCoreTests
  - docs/rules/principles.md
---

# Settings Persistence

## モデル

- `Packages/KoechoKit/Sources/KoechoCore/Settings.swift` は各 `*Settings` の root。`UserDefaults` を 1 つ受け取り、sub-settings 全部へ同じ instance を渡す。
- 各 `*Settings` は `@MainActor @Observable`。private backing store を持ち、public property の setter で `save()` する。
- scalar 値は `UserDefaults` key に直接保存し、配列・値型は JSON `Data` に encode する。
- optional shortcut は `nil` を `Data()` sentinel として保存する pattern がある。`removeObject` と混ぜると decode 時の default と nil の区別が壊れやすい。

## UI との接続

- `Koecho/SettingsView.swift` が Settings window の root。各 page は `SettingsPage` で切り替える。
- General / Voice Input / Hotkey / Script / Replacement / History / App Icon / Volume Ducking は App target の SwiftUI view で編集し、Core の settings model を直接 mutate する。
- SpeechAnalyzer locale や model download は `VoiceInputSection` と `SpeechAnalyzerLocaleManager` をまたぐ。SpeechAnalyzer の外部 API 罠は [SpeechAnalyzer 外部知見](speechanalyzer-external-notes.md)。

## 設定追加の手順

1. Core の該当 `*Settings` に backing store、public property、load、save、default/clamp を追加する。
2. `SettingsTests` または該当 `*SettingsTests` に persistence / default / corrupt data / nil sentinel のテストを追加する。
3. App target の Settings view に UI を追加する。
4. runtime side effect が必要なら `KoechoApp` の `onChange`、または関連 service の設定参照を更新する。

## 読む場所

- hotkey 設定: `Packages/KoechoKit/Sources/KoechoCore/HotkeySettings.swift`, `Packages/KoechoKit/Sources/KoechoCore/HotkeyConfig.swift`, `Koecho/HotkeySettingsView.swift`, [Hotkey / Paste / Selection](hotkey-paste-selection.md)。
- script 設定: `Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift`, `Packages/KoechoKit/Sources/KoechoCore/Script.swift`, `Koecho/ScriptManagementView.swift`, [Scripts / Replacements / History](scripts-replacements-history.md)。
- replacement 設定: `Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift`, `Packages/KoechoKit/Sources/KoechoCore/ReplacementRule.swift`, `Koecho/ReplacementRuleManagementView.swift`。
- voice input 設定: `Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift`, `Koecho/VoiceInputSection.swift`, [Speech / Audio](speech-audio.md)。
