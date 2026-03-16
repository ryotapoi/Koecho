# Backlog

## v1.0.1 — コード改善（healthcheck 2026-03-15）

- [x] T9: AudioDeviceManager の責務分割
- [ ] T10: eligibleScripts フィルタの一元化
- [ ] T11: SpeechAnalyzerEngine タイムアウト待機パターンの共通化
- [ ] T12: auto-run ピッカー UI の状態操作ロジック共通化
- [ ] T13: Logger subsystem 文字列リテラルの定数化
- [ ] T14: isProcessTrusted() の重複定義解消
- [ ] T15: ScriptSettings / ReplacementSettings の try? encode 一貫性修正
- [ ] T16: SpeechAnalyzerLocaleManager のテストカバレッジ改善

## v1.1 — 音声入力オフモード

- [ ] T17: 音声入力オフモード（キーボード専用モード）

## Later

- [ ] T8: 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新

---

## 詳細

### T8: 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新
- 現状: Settings で言語をダウンロード/リリースした後、Settings ウィンドウを閉じないとメニューバーの Recognition Language サブメニューに反映されない
- 理想: Settings 内でダウンロード完了した時点で即反映
- 方針: NotificationCenter か AppState にプロパティを追加し、LanguageManagementSheet のダウンロード完了を KoechoApp に通知する

### T9: AudioDeviceManager の責務分割
- 発見: 2026-03-15 healthcheck
- 現状: `KoechoPlatform/AudioDeviceManager.swift`（735行 / CRITICAL）に3つの責務が混在
  1. デバイス列挙・管理（L258-374）: `enumerateInputDevices()`, `isAggregateDevice()` 等
  2. 入力音量の読み取り・変更（L376-487）: `setupVolumeMonitoring()`, `setInputVolume()` 等
  3. AUHAL レベルメータ（L489-735）: `auhalInputCallback` を含む約250行の低レベル実装
- `@MainActor @Observable` クラスに `nonisolated(unsafe)` プロパティが5個散在（AUHAL コールバックからの直接参照のため）。Swift Concurrency の型安全を部分的に破っている
- 分割候補:
  - `AudioDeviceListing`: デバイス列挙静的メソッド群を独立した型に
  - `AudioInputLevelMonitor`: AUHAL セットアップ・コールバック・バッファ管理を独立クラスへ。`nonisolated(unsafe)` の影響範囲を局所化
- 影響先: `SpeechAnalyzerEngine.swift`（L206で静的メソッド呼び出し）、`GeneralSettingsView.swift`（L242でインスタンス化）

### T10: eligibleScripts フィルタの一元化
- 発見: 2026-03-15 healthcheck
- 現状: `scripts.filter { !$0.requiresPrompt }` が3か所に独立して存在
  - `Koecho/InputPanelContent.swift:164`
  - `Koecho/KoechoApp.swift:172`
  - `Koecho/ScriptExecutionService.swift:82`
- リスク: 条件変更（例: disabled フラグ追加）時に更新漏れ
- 方針: `ScriptSettings` に `eligibleAutoRunScripts: [Script]` computed property を追加し、3か所から参照

### T11: SpeechAnalyzerEngine タイムアウト待機パターンの共通化
- 発見: 2026-03-15 healthcheck
- 現状: `withTaskGroup(of: Bool.self)` で「本処理タスク」と「1秒スリープタスク」を競争させるイディオムが完全に同一の実装で3箇所存在
  - `SpeechAnalyzerEngine.swift:100-110`（`stop()` の finalizeTask 待ち）
  - `SpeechAnalyzerEngine.swift:115-126`（`stop()` の resultTask 待ち）
  - `SpeechAnalyzerEngine.swift:370-381`（`restartTranscriber()` の oldResultTask 待ち）
- 方針: ファイル内プライベートヘルパー `waitWithTimeout<T>(_ task: Task<T, Never>, seconds: Double) async -> Bool` に切り出し

### T12: auto-run ピッカー UI の状態操作ロジック共通化
- 発見: 2026-03-15 healthcheck
- 現状: auto-run スクリプト選択の「✓ None / None」表示＋`autoRunScriptId` 更新が2か所に重複
  - `Koecho/InputPanelContent.swift:175-196`（パネル内ドロップダウン）
  - `Koecho/KoechoApp.swift:180-203`（メニューバーフラットリスト）
- レイアウトが異なるため View の共通化は困難。状態操作ロジックのみ共通化が現実的

### T13: Logger subsystem 文字列リテラルの定数化
- 発見: 2026-03-15 healthcheck
- 現状: `"com.ryotapoi.koecho"` が19ファイルにハードコード。Bundle ID は `com.ryotapoi.Koecho`（大文字K）で別の値
- 特に `HistoryStore.swift:16` ではアプリケーションサポートディレクトリのパス構築に使用。Bundle ID 変更時にデータ永続化パスへの影響が自動伝播しない
- 方針: KoechoCore に定数（例: `static let subsystem = "com.ryotapoi.koecho"`）を定義し、全ファイルから参照

### T14: isProcessTrusted() の重複定義解消
- 発見: 2026-03-15 healthcheck
- 現状: `AccessibilityClient`（`AccessibilityClient.swift:5,13`）と `CGEventClient`（`CGEventClient.swift:7,16`）が両方とも `isProcessTrusted() -> Bool` を持ち、Live 実装は同じ `AXIsProcessTrusted()` を呼ぶ
- プロトコル統合よりも、KoechoPlatform 内に共通ヘルパー関数（例: `func checkAccessibilityTrust() -> Bool`）を切り出し、両 Live 実装から参照する形が整合的

### T15: ScriptSettings / ReplacementSettings の try? encode 一貫性修正
- 発見: 2026-03-15 healthcheck
- 現状: `save()` メソッド内で `_scripts` の encode は `do/catch + logger.error` で処理しているのに、shortcut key の encode だけ `try?` でサイレントに握り潰している
  - `ScriptSettings.swift:122`: `defaults.set(try? JSONEncoder().encode(shortcut), forKey: "autoRunShortcut")`
  - `ReplacementSettings.swift:92`: `defaults.set(try? JSONEncoder().encode(shortcut), forKey: "replacementShortcut")`
- encode 失敗時に `defaults.set(nil, ...)` が呼ばれ UserDefaults からキーが消えるが、ログにも出ない
- 方針: 同じ `save()` 内の他の encode と同様に `do/catch + logger.error` に統一

### T16: SpeechAnalyzerLocaleManager のテストカバレッジ改善
- 発見: 2026-03-15 healthcheck
- 現状: カバレッジ 13.68%（190実行可能行中26行のみテスト済み）
- `loadLocales(currentSelection:)` の選択補正ロジック（正規化マッチ、ja-JP フォールバック、先頭要素フォールバック）がほぼ未テスト
- 純粋な配列操作の分岐を多く含み、`AssetInventory` への依存を除けばモック化しやすい
- 最もコストパフォーマンスの高いカバレッジ改善対象

### T17: 音声入力オフモード（キーボード専用モード）
- 動機: ターミナル系アプリで日本語（漢字変換が必要な言語）を入力すると表示がおかしくなることがある。Koecho をエディタ代わりに使い「書いてから貼り付ける」ワークフローに対応する
- 概要: パネル表示時に音声入力エンジンを起動せず、キーボード入力のみで使えるモード
- オンオフの切り替え場所は要検討（Settings / メニューバー / パネル内 等）
