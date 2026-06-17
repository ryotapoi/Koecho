---
regen: full
sources:
  - docs/rules/information-management.md
---

# Koecho llm-wiki

Koecho の横断的な技術知見を、変更時に参照しやすい地図として編む。

| ページ | regen | 内容 | 主な sources |
|---|---|---|---|
| [実装地図](feature-map.md) | full | 作業テーマから入口ファイル・テスト・ADR へ辿る索引 | `docs/rules/architecture.md`, `Koecho/`, `Packages/KoechoKit/` |
| [App Entry / State](app-entry-state.md) | compiled | `KoechoApp`、`AppState`、入力パネル生成、Settings window の接続 | `Koecho/KoechoApp.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift` |
| [Settings Persistence](settings-persistence.md) | compiled | `Settings` と各 `*Settings`、UserDefaults 永続化、設定 UI の読む場所 | `Packages/KoechoKit/Sources/KoechoCore/Settings.swift`, `Koecho/SettingsView.swift` |
| [Scripts / Replacements / History](scripts-replacements-history.md) | compiled | スクリプト実行、置換ルール、履歴保存、auto-run の流れ | `Koecho/ScriptExecutionService.swift`, `Koecho/ReplacementService.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift` |
| [Hotkey / Paste / Selection](hotkey-paste-selection.md) | compiled | グローバルホットキー、選択テキスト取得、クリップボード復元つきペースト | `Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/SelectedTextReader.swift` |
| [macOS / AppKit](macos-appkit.md) | compiled | MenuBarExtra、LSUIElement、NSPanel、外部プロセス、macOS UI の落とし穴 | `Koecho/MenuBarContent.swift`, `Koecho/InputPanel.swift`, `Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift` |
| [音声入力テキストライフサイクル](voice-input-text-lifecycle.md) | compiled | NSTextView、volatile テキスト、ディクテーション、InputPanelController 周辺 | `Koecho/VoiceInputTextView.swift`, `Koecho/VoiceInputCoordinator.swift` |
| [Speech / Audio](speech-audio.md) | compiled | SpeechAnalyzer、AVAudioEngine、CoreAudio デバイス管理 | `Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift` |
| [SpeechAnalyzer 外部知見](speechanalyzer-external-notes.md) | none | macOS 26 SpeechAnalyzer の実測、API 罠、テスト上の回避策 | `Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerLocaleManager.swift` |
| [Testing](testing.md) | compiled | TEST_HOST、UserDefaults 分離、OS 連携テストの避け方 | `KoechoTests/`, `Packages/KoechoKit/Tests/` |
| [Swift / Settings / Modules](swift-settings-modules.md) | compiled | Observation、設定モデル、モジュール境界、Swift 言語上の罠 | `Packages/KoechoKit/Sources/KoechoCore/`, `docs/decisions/0018-spm-module-separation.md` |
