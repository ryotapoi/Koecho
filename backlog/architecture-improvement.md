# アーキテクチャ改善計画

TCA は使わず、現行の `@Observable + Protocol DI` を延長して改善する。
分析レポート: [tmp/tca-analysis.md](../tmp/tca-analysis.md)

---

## Phase 1: View からロジック抽出 + Client Protocol 導入

View 内に埋め込まれたビジネスロジック（現在テスト不可）を抽出し、UnitTest 可能にする。

### 1a. ReplacementRule.validate() 抽出

- 対象: `ReplacementRuleEditView` (L6-14), `AddReplacementRuleView` (L13-25)
- 問題: 正規表現バリデーションが View に重複実装
- 改善: `ReplacementRule` に `validate() -> String?` を追加

### 1b. SpeechAnalyzerLocaleManager 抽出

- 対象: `GeneralSettingsView` 内の `SpeechAnalyzerLocalePicker` (約 199 行)
- 問題: locale 列挙、モデル download/release、進捗管理が全て View 内
- 改善: `SpeechAnalyzerLocaleManager` (@Observable class) に切り出し

### 1c. HistoryView の clipboard 操作を service に

- 対象: `HistoryView` (L63-76) の `copyEntry()`
- 問題: NSPasteboard 直接操作が View 内
- 改善: service または HistoryStore のメソッドに移動

### 1d. Apple API Client Protocol 定義

- 対象: `ClipboardPaster`, `SelectedTextReader` の内部 API 呼び出し
- 問題: CGEvent / AXUIElement を直接呼んでいてモック不可
- 改善: `AccessibilityClient`, `CGEventClient` protocol を定義し、live/test 実装を分離

---

## Phase 2: InputPanelController 分割

849 行の God Object を責務ごとのサービスに分割。race condition のテストを可能にする。

### 2a. PanelLifecycleManager

- show/hide/clear の状態管理
- フォアグラウンドアプリの記憶・復元

### 2b. TextConfirmationService

- confirm フロー: 置換適用 -> auto-run script -> paste
- キャンセルとの race condition をテスト可能に

### 2c. ScriptExecutionService

- スクリプト実行 + プロンプト処理
- エラーハンドリング（タイムアウト、非ゼロ終了、空出力）

### 2d. VoiceInputCoordinator

- エンジンライフサイクル（生成・開始・停止・切り替え）
- delegate routing（finalize / volatile / error）
- voiceInsertionPoint の管理

### 2e. ReplacementService

- 置換ルール適用 + プレビュー
- voiceInsertionPoint の調整

---

## Phase 3: Settings 分割

382 行の一枚岩 Settings を domain ごとに分割。テストの初期化コスト削減と View の結合度低下。

### 3a. Sub-settings に分離

```
Settings
├─ VoiceInputSettings
├─ HotkeySettings
├─ ScriptSettings (CRUD メソッド含む)
├─ ReplacementRuleSettings (CRUD メソッド含む)
├─ HistorySettings
└─ PasteSettings
```

### 3b. View が必要な設定だけ受け取る

- GeneralSettingsView -> VoiceInputSettings + PasteSettings
- HotkeySettingsView -> HotkeySettings
- ScriptManagementView -> ScriptSettings
- ReplacementRuleManagementView -> ReplacementRuleSettings

---

## Phase 4: SPM モジュール分離

コンパイル境界で依存方向を強制。ビルド高速化、再利用性、テスト境界の明確化。

### 4a. KoechoCore パッケージ

- pure Swift、macOS API 非依存
- Models: Script, ShortcutKey, HotkeyConfig, ReplacementRule, HistoryEntry
- Services: ScriptRunner, ModifierTapDetector, ReplacementEngine
- Settings: 分割された設定群

### 4b. KoechoPlatform パッケージ

- macOS 依存、全てプロトコル準拠
- ClipboardPaster, SelectedTextReader, HotkeyService
- AudioDeviceManager, OutputVolumeDucker
- VoiceInput: DictationEngine, SpeechAnalyzerEngine

### 4c. Koecho アプリターゲット

- UI + orchestration のみ
- Views/, InputPanelController, KoechoApp
