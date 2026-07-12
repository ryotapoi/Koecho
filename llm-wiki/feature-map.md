---
regen: full
sources:
  - docs/rules/architecture.md
  - docs/rules/scope.md
  - Koecho
  - Packages/KoechoKit/Sources/KoechoCore
  - Packages/KoechoKit/Sources/KoechoPlatform
  - KoechoTests
  - Packages/KoechoKit/Tests
  - docs/decisions
---

# 実装地図

作業テーマから、最初に読むファイル・関連テスト・設計判断へ辿る索引。

| 触るテーマ | 入口 | あわせて読む | テスト |
|---|---|---|---|
| アプリ起動、メニューバー、Settings window | `Koecho/KoechoApp.swift`, `Koecho/MenuBarContent.swift` | [App Entry / State](app-entry-state.md), [macOS / AppKit](macos-appkit.md), docs/decisions/0002-window-scene-tabview-for-settings.md | `KoechoTests/MenuBarContentTests.swift` |
| 入力パネルの表示、確定、キャンセル | `Koecho/InputPanelController.swift`, `Koecho/PanelLifecycleManager.swift`, `Koecho/InputPanel.swift` | [音声入力テキストライフサイクル](voice-input-text-lifecycle.md), docs/decisions/0017-split-inputpanelcontroller-into-services.md | `KoechoTests/InputPanelController*Tests.swift`, `KoechoTests/PanelLifecycleManagerTests.swift` |
| テキスト入力、Dictation、volatile 表示、置換 preview tooltip | `Koecho/VoiceInputTextView.swift`, `Koecho/ReplacementPreviewTooltip.swift`, `Koecho/VoiceInputCoordinator.swift`, `Koecho/DictationEngine.swift` | [音声入力テキストライフサイクル](voice-input-text-lifecycle.md), docs/decisions/0001-auto-start-dictation-via-startdictation-selector.md, docs/decisions/0010-nstextview-subclass-replacing-swiftui-texteditor.md | `KoechoTests/VoiceInputTextViewTests.swift`, `KoechoTests/ReplacementPreviewTooltipTests.swift`, `KoechoTests/VoiceInputCoordinatorTests.swift`, `KoechoTests/DictationEngineTests.swift` |
| SpeechAnalyzer と audio device | `Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerLocaleManager.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift` | [Speech / Audio](speech-audio.md), [SpeechAnalyzer 外部知見](speechanalyzer-external-notes.md), docs/decisions/0012-speechanalyzer-voice-input-engine.md, docs/decisions/0013-auhal-for-level-metering.md | `Packages/KoechoKit/Tests/KoechoPlatformTests/SpeechAnalyzer*Tests.swift`, `Packages/KoechoKit/Tests/KoechoPlatformTests/Audio*Tests.swift` |
| スクリプト実行、prompt、auto-run | `Koecho/ScriptExecutionService.swift`, `Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift`, `Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift` | [Scripts / Replacements / History](scripts-replacements-history.md), [macOS / AppKit](macos-appkit.md), docs/decisions/0006-script-path-as-shell-command-string.md | `KoechoTests/ScriptExecutionServiceTests.swift`, `Packages/KoechoKit/Tests/KoechoCoreTests/ScriptRunnerTests.swift`, `Packages/KoechoKit/Tests/KoechoCoreTests/ScriptSettingsTests.swift` |
| 置換ルール、プレビュー、手動適用 | `Koecho/ReplacementService.swift`, `Packages/KoechoKit/Sources/KoechoCore/ReplacementRule.swift`, `Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift` | [Scripts / Replacements / History](scripts-replacements-history.md), docs/decisions/0003-manual-trigger-for-replacement-rules.md, docs/decisions/0020-multiple-patterns-per-replacement-rule.md | `KoechoTests/ReplacementServiceTests.swift`, `Packages/KoechoKit/Tests/KoechoCoreTests/ReplacementRuleTests.swift`, `Packages/KoechoKit/Tests/KoechoCoreTests/ReplacementSettingsTests.swift` |
| ホットキー | `Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift`, `Packages/KoechoKit/Sources/KoechoCore/ModifierTapDetector.swift`, `Packages/KoechoKit/Sources/KoechoCore/HotkeyConfig.swift` | [Hotkey / Paste / Selection](hotkey-paste-selection.md), docs/decisions/0007-double-tap-detection-with-pure-state-machine.md, docs/decisions/0008-nsview-based-shortcut-key-recorder.md | `Packages/KoechoKit/Tests/KoechoPlatformTests/HotkeyServiceTests.swift`, `Packages/KoechoKit/Tests/KoechoCoreTests/ModifierTapDetectorTests.swift` |
| 選択テキスト取得、ペースト、クリップボード復元 | `Packages/KoechoKit/Sources/KoechoPlatform/SelectedTextReader.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/CGEventClient.swift` | [Hotkey / Paste / Selection](hotkey-paste-selection.md), docs/rules/scope.md | `Packages/KoechoKit/Tests/KoechoPlatformTests/SelectedTextReaderTests.swift`, `Packages/KoechoKit/Tests/KoechoPlatformTests/ClipboardPasterTests.swift` |
| 設定モデル、UserDefaults、設定 UI | `Packages/KoechoKit/Sources/KoechoCore/Settings.swift`, `Packages/KoechoKit/Sources/KoechoCore/*Settings.swift`, `Koecho/SettingsView.swift` | [Settings Persistence](settings-persistence.md), [Swift / Settings / Modules](swift-settings-modules.md), docs/rules/principles.md | `Packages/KoechoKit/Tests/KoechoCoreTests/*SettingsTests.swift` |
| 履歴 | `Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift`, `Packages/KoechoKit/Sources/KoechoCore/HistoryEntry.swift`, `Packages/KoechoKit/Sources/KoechoCore/HistorySettings.swift`, `Koecho/HistoryView.swift` | [Scripts / Replacements / History](scripts-replacements-history.md), docs/decisions/0004-history-storage-as-json-file.md | `Packages/KoechoKit/Tests/KoechoPlatformTests/HistoryStoreTests.swift`, `Packages/KoechoKit/Tests/KoechoCoreTests/HistorySettingsTests.swift` |

## 境界

- `KoechoCore`: Foundation 中心の model / settings / pure logic。AppKit、Carbon、CoreAudio、Speech を入れない。
- `KoechoPlatform`: macOS integration。CoreAudio、AVFoundation、Accessibility、CGEvent、SpeechAnalyzer、`AppState` を持つ。
- `Koecho`: SwiftUI / AppKit UI、`NSTextView`、`NSPanel`、`DictationEngine`、controller/service wiring を持つ。
