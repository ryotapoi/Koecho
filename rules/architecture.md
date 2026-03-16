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
- 音声入力エンジン実装（SpeechAnalyzerEngine）
- AppState（アプリ全体の状態管理）

### Koecho (App target)
- SwiftUI View（SettingsView, InputPanelContent 等）
- AppKit カスタムビュー（InputPanel, VoiceInputTextView 等）
- コントローラー（InputPanelController, PanelLifecycleManager 等）
- DictationEngine（NSTextView 依存のため App target に配置）
- アプリエントリポイント（KoechoApp）

## テストターゲット

- **KoechoTests**: App target のテスト（Koecho スキームで実行）
- **KoechoPlatformTests**: KoechoPlatform のテスト（`swift test` で実行）
- **KoechoCoreTests**: KoechoCore のテスト（`swift test` で実行）
