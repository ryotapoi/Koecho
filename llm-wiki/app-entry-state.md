---
regen: compiled
sources:
  - Koecho/KoechoApp.swift
  - Koecho/MenuBarContent.swift
  - Koecho/PanelLifecycleManager.swift
  - Koecho/InputPanelController.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerLocaleManager.swift
  - docs/decisions/0002-window-scene-tabview-for-settings.md
  - docs/decisions/0017-split-inputpanelcontroller-into-services.md
---

# App Entry / State

## 起動と所有関係

- `Koecho/KoechoApp.swift` が app entry。`AppState`、`HistoryStore`、`InputPanelController?`、`HotkeyService?`、SpeechAnalyzer の downloaded locale list を `@State` で所有する。
- `Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift` は UI と platform service が共有する中核状態。設定本体は `settings: Settings` に集約され、入力パネル状態、prompt、volatile prompt、script 実行中、voice engine status などを持つ。
- `InputPanelController` は遅延生成。`ensurePanelController()` で初回表示時に作られ、`AppState` と `HistoryStore` を受け取る。
- テスト時は `KoechoApp.isTesting` で起動副作用を止める。詳細は [Testing](testing.md)。

## MenuBarExtra からの流れ

- MenuBarExtra は `MenuBarContent` に `appState`、`historyStore`、downloaded locales、panel toggle、language switch closure を渡す。
- panel open/confirm は `togglePanel()` → `InputPanelController.showPanel()` または `confirm()`。
- Settings window は `openWindow(id: "settings")` 後、LSUIElement 対策として `MenuBarContent.bringSettingsWindowToFront()` で前面化する。詳細は [macOS / AppKit](macos-appkit.md)。
- SpeechAnalyzer locale をメニューバーから切り替えた場合は、設定を書き換えたうえで表示中 panel の engine を `switchEngine()` で再生成する。

## Settings window と副作用

- `SettingsView` には `settings` と `historyStore` を渡す。Speech locale の変更後は `refreshDownloadedLocales()` で menu 側の locale list を再同期する。
- app icon は `appState.settings.appIcon.selectedAppIcon` の `onChange` で `AppIconApplicator.apply` へ渡す。
- history purge は MenuBarExtra の `onChange(of: appState.isInputPanelVisible, initial: true)` 内で 1 回だけ走る。

## 変更時の入口

- アプリ全体の状態追加: `AppState` に置く前に、その状態が設定永続化か一時 UI 状態かを分ける。永続化なら [Settings Persistence](settings-persistence.md)。
- panel の confirm/cancel/show: `InputPanelController` と `PanelLifecycleManager` を先に読む。テキストや voice の副作用は [音声入力テキストライフサイクル](voice-input-text-lifecycle.md) を併読する。
- menu 項目追加: `MenuBarContent` と `KoechoApp` の closure wiring を読む。Settings window foregrounding には触れない。
