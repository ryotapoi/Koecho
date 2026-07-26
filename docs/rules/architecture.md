# Architecture

## モジュール構成

```
Koecho (App target)
├── KoechoPlatform   macOS 固有の実装（CoreAudio, AVFoundation, Accessibility 等）
│   └── KoechoCore   プラットフォーム非依存のモデル・設定・ロジック
└── SwiftUI / AppKit  UI 層
```

## 依存方向

```
Koecho → KoechoPlatform → KoechoCore
```

- **KoechoCore**: Foundation のみ。macOS 固有 API (Carbon, CoreAudio, AppKit 等) を import しない
- **KoechoPlatform**: KoechoCore に依存。macOS 固有 API を使用する
- **Koecho (App)**: KoechoPlatform と KoechoCore に依存。SwiftUI View、AppKit カスタムビュー、アプリエントリポイントを含む

依存は上から下への一方向のみ。逆方向（KoechoCore → KoechoPlatform 等）は禁止。

## 各モジュールの責務

### KoechoCore
- データモデル（Script, ReplacementRule, HotkeyConfig, HistoryEntry 等）
- 設定クラス（Settings, 各 *Settings）
- プラットフォーム非依存ロジック（ScriptRunner, ModifierTapDetector 等）
- プロトコル定義（VoiceInputEngine 等）

### KoechoPlatform
- macOS 固有サービス（HotkeyService, ClipboardPaster, SelectedTextReader 等）
- オーディオデバイス管理（AudioDeviceManager, AudioDeviceListing, AudioInputLevelMonitor 等）
- 出力音量制御（OutputVolumeDucker）
- 音声入力エンジン実装（SpeechAnalyzerEngine）
- AppState（アプリ全体の状態管理）

### Koecho (App target)
- SwiftUI View（SettingsView, InputPanelContent 等）
- AppKit カスタムビュー（InputPanel, VoiceInputTextView 等）
- コントローラー（InputPanelController, PanelLifecycleManager 等）
- DictationEngine（NSTextView 依存のため App target に配置）
- アプリエントリポイント（KoechoApp）

## 責務境界

モジュール分割とは別に、以下の所有権・分割を守る。

### 確定入力テキストの所有権

- 確定入力テキストの正本は `AppState.inputText`。`private(set)` とし、書き込みは `setInputText(_:)` だけを通す
- `VoiceInputTextView` は表示・編集バッファであり、marked text と volatile text を含む。確定挿入・volatile 挿入・隣接句読点の重複除去・typing attributes・callback suppression を所有する
- `TextViewOperating` は text storage と callback suppression state を公開しない。コントローラー・サービスからこれらを直接操作しない
- SwiftUI Binding によるテキスト同期は使わない。外向きは `didChangeText()` からの callback、内向きは `updateNSView` で行い、フィードバックループは suppression フラグで防ぐ

### InputPanel まわりのサービス分割

`InputPanelController` は薄いコーディネーター（init wiring, confirm / cancel の統括, callback dispatch）に留め、機能は以下のサービスが持つ。共有のテキストビュー操作は `TextViewOperating` protocol を介する。

- `ReplacementService`: 置換ルールの適用と preview
- `ScriptExecutionService`: スクリプト実行と内蔵テキスト操作の dispatch
- `VoiceInputCoordinator`: 音声入力エンジンとの仲介、`voiceInsertionPoint` の所有。音声入力エンジンの delegate は本 Coordinator に直接設定し、delegate callback も本 Coordinator が所有する。`InputPanelController` は delegate 経路に含めない
- `PanelLifecycleManager`: パネルの表示・非表示・状態リセット

### ホットキー検出のタイマー所有

`ModifierTapDetector` は副作用を持たない state machine として保つ。ダブルタップ判定のタイマーは `HotkeyService` が所有し、期限切れを `expireDoubleTapWindow()` で detector に通知する。detector 内部にタイマーを持たせない。

### 設定 UI の構成

設定画面は `Window` scene + `NavigationSplitView`（固定サイドバー + detail）でホストする。`Settings` scene は使わない（MenuBarExtra のみのアプリでは Cmd+, が機能しないため）。

### 履歴の保存

- 履歴本体は `~/Library/Application Support/com.ryotapoi.koecho/history.json` に JSON ファイルとして保存する
- 履歴の設定値（有効フラグ・最大件数・保持日数）は UserDefaults に保持する

## テストターゲット

- **KoechoTests**: App target のテスト（Koecho スキームで実行）
- **KoechoPlatformTests**: KoechoPlatform のテスト（`swift test` で実行）
- **KoechoCoreTests**: KoechoCore のテスト（`swift test` で実行）
