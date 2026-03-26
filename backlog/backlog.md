# Backlog

## v1.4 — 置換ルール UI 改善

### 1. 複数パターン置換（単純置換モード）
- [x] 単純置換モードで1つのルールに複数の置換元パターンを登録できるようにする
  - 例: 「GitHブ」「ギットHub」→「GitHub」を1ルールで設定
- [x] UI: Pattern 欄を縦リスト化（TextField + [+][-] ボタン）
- [x] 内部実装: 単純な文字列置換を複数パターンで実行（要検討: 性能・正確性次第で内部正規表現も選択肢）
- [x] データモデル: `pattern: String` → `patterns: [String]` に変更 + マイグレーション

### 2. 置換ルール UI 整理
- [x] 単純置換と正規表現でUIを分ける
  - 単純置換: 複数 Patterns（縦リスト）+ Replacement + Match Whole Word
  - 正規表現: Pattern（単一）+ Replacement（キャプチャグループヒント）
  - Match Whole Word は単純置換専用（現状通り、正規表現時は非表示）

## RenderPreview 対応 — 全画面 #Preview 追加 + ワークフロー統合

UI 変更時に Xcode MCP の `RenderPreview` で視覚確認するための基盤整備。
UnitTest ほどの厳密さではないが「規定の確認手段」として維持する。

### Phase 1: 全 View に #Preview を追加

既存の全 SwiftUI View に `#Preview` マクロを追加し、`RenderPreview` で確認可能にする。

**KoechoCore のみ依存（Preview 容易）:**
- [x] ReplacementRuleEditView — 単純置換 / 正規表現の各状態
- [x] AddReplacementRuleView — 空状態 / 入力済み
- [x] ReplacementRuleManagementView — ルール0件 / 複数件
- [x] ScriptEditView — 空 / 入力済み / requiresPrompt on/off
- [x] ScriptManagementView — スクリプト0件 / 複数件
- [x] PromptInputView — 空 / 入力済み
- [x] AutoRunScriptMenuContent — スクリプトあり / なし
- [x] VolumeDuckingSection — 各設定状態
- [x] GeneralSettingsView — 各設定状態

**KoechoPlatform 依存（Preview に工夫が必要）:**
- [x] HotkeySettingsView — 各修飾キー / タップモード
- [x] HistoryView — 履歴0件 / 複数件
- [x] SettingsView — 各タブ
- [x] InputPanelContent — テキストあり / なし / スクリプト実行中
- [x] InputPanelToolbar — 各状態
- [x] VoiceInputSection — macOS 26 依存のため要検討
- [x] MenuBarContent — AppState + closures のため要検討

### Phase 2: ワークフロー・スキルへの組み込み

- [x] `rules/workflow.md` Step 3（実装）: View 変更・追加時に `#Preview` を書く/更新し、RenderPreview で確認する手順を追加（UnitTest の RED→GREEN と同じ流れ）
- [x] `rules/workflow.md` Step 4（実装レビュー）: 変更 View の `#Preview` を RenderPreview で再確認する手順を追加（レビュアーによる視覚チェック）
- [x] `/review-code-all` スキル: 変更された View に `#Preview` があれば RenderPreview でレンダリングし視覚確認するステップを追加
- [x] レビュー観点:
  - レイアウト崩れ: テキスト切れ、要素の重なり、意図しない余白
  - 状態の網羅: 空状態 / 通常 / エッジケースの Preview が揃っているか
  - 変更の影響: 今回変更した View 以外の Preview が壊れていないか
  - フレームサイズ: Preview の `.frame()` が適切か（巨大/空にならないか）
- [x] Step 1（計画）: UI 調査目的での RenderPreview 利用を明記

### 技術ノート

- App target に全 View があるため `public` 化不要
- `@Previewable @State` で Binding を作る。`.frame()` でサイズ指定必須
- KoechoPlatform 依存の View は Preview 用のモックやサンプルデータの工夫が必要
- SPM パッケージモジュール使用ファイルは事前 `BuildProject` が必要

---

## Bug — restartTranscriber クラッシュ（CoreAudio IO スレッド）

- 発生: 2026-03-23 23:34, v1.3.0 リリース版, 約12時間使用後
- クラッシュログ: `~/Library/Logs/DiagnosticReports/Koecho-2026-03-23-233412.ips`

### 症状
- `EXC_BAD_ACCESS (SIGSEGV)` — `KERN_INVALID_ADDRESS at 0x0000000000000000`
- クラッシュスレッド: `com.apple.audio.IOThread.client` で PC=0x0（NULL 関数ポインタ呼び出し）
- CoreAudio `HALC_ProxyIOContext::IOWorkLoop()` 内で発生

### 原因分析
`SpeechAnalyzerEngine.restartTranscriber()` (SpeechAnalyzerEngine.swift:341) のレースコンディション:

1. L348: `audioEngine.inputNode.removeTap(onBus: 0)` — 古い tap を除去
2. L349-360: analyzer の停止待機（`await` で他スレッドに制御を渡す）
3. L375: `installAudioTap()` — 新しい tap をインストール

`removeTap` は tap 登録を解除するが、CoreAudio の IO スレッドが既にディスパッチ中のコールバック完了を待たない。`removeTap` → `await` の間に IO スレッドが解放済みのコールバック関数ポインタを呼び出し、NULL 参照でクラッシュ。

呼び出し元: `VoiceInputCoordinator.restartTranscriberIfNeeded()` (VoiceInputCoordinator.swift:280)

### 他のクラッシュログ（別件）
- 3/20 (v1.1.0), 3/21 (v1.2.0): Debug 実行で起動直後にクラッシュ。`DictationEngine.sendStartDictation()` → TSM Ironwood 関連。デバッグ固有の問題で本件とは無関係

### 修正方針
- [x] `restartTranscriber()` で `removeTap` 後に CoreAudio IO スレッドの完了を安全に待つ仕組みを入れる
- [x] `audioEngine.stop()` / `audioEngine.start()` で IO スレッドのライフサイクルを明示的に制御する案を検討

## Bug — カーソル移動時にテキスト重複（SpeechAnalyzerEngine）

- 発生条件: 長めに音声入力中、仮テキスト（薄い文字）が表示された状態で Ctrl+B 長押しなどカーソル移動すると、テキストが重複する
- 改行（Enter）では発生しない
- SpeechAnalyzerEngine（macOS 26+）のみ。DictationEngine はカーソル移動時の処理をスキップしている

### 原因候補（確度 70-80%、要再現確認）

`didFinalize`（改行時）と `didUpdateVolatile`（カーソル移動後の仮テキスト更新時）でデュプリケーション防止の強さが非対称:

| パス | トリガー | デュプリケーション防止 |
|------|---------|-------------------|
| `didFinalize` | Enter | `stripOverlappingPrefix()` — 最大512文字の部分一致 (強い) |
| `didUpdateVolatile` | Ctrl+B 後 | `hasPrefix()` — 完全前方一致のみ (弱い) |

カーソル移動 → `handleCursorMoved()` → 仮テキスト確定 → SpeechAnalyzer が次の仮テキスト送信 → `didUpdateVolatile` の弱いチェックを素通り → 重複挿入、という流れが疑われる。

ただし `voiceInsertionPoint` の位置ずれなど他の要因も排除できていない。

### 関連コード
- `VoiceInputCoordinator.swift`: handleCursorMoved (L113-129), didUpdateVolatile (L196-219), didFinalize (L143-194), stripOverlappingPrefix (L291-305)
- `VoiceInputTextView.swift`: setSelectedRange (L351-356), finalizeVolatileText (L87-107)
- ADR 0016: accumulated-text-overlap-removal-for-speechanalyzer

### 修正進め方
- [ ] 再現手順の確立（長文音声入力中に Ctrl+B でカーソル移動）
- [ ] ログ仕込み: `didUpdateVolatile` で suppression 判定の入出力を記録
- [ ] 原因特定後に修正（候補: `didUpdateVolatile` にも `stripOverlappingPrefix` 相当を適用）
- [ ] ユーザー確認で再発しないことを検証

## Later

- [ ] 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新

---

## 詳細

### 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新
- 現状: Settings で言語をダウンロード/リリースした後、Settings ウィンドウを閉じないとメニューバーの Recognition Language サブメニューに反映されない
- 理想: Settings 内でダウンロード完了した時点で即反映
- 方針: NotificationCenter か AppState にプロパティを追加し、LanguageManagementSheet のダウンロード完了を KoechoApp に通知する
