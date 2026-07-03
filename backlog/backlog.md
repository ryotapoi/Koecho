# Backlog

## v1.6.0 — テスト健全性の即効修正

- [ ] DictationEngine の startDictation 実送信をクロージャ注入にして flaky クラッシュを直す
  - 2026-07-03 に全 189 件実行で `applyReplacementRulesNowReplacesText` と `stopFromListeningTransitions` が「Crash: Koecho at \<external symbol\>」で失敗（単独再実行では成功）。クラッシュレポートで原因特定済み: `DictationEngine.sendStartDictation()`（`DictationEngine.swift:75`）が実の `NSApp.sendAction(startDictation:)` を送信し、HIToolbox / TSM 内で SIGSEGV（KERN_INVALID_ADDRESS）
  - `stopFromListeningTransitions` は 400ms 待つため実送信に到達する（`DictationEngineTests.swift:72`）。また `start()` の retryTask はクロージャが engine を強参照し、InputPanel も NSApp が保持するため、テスト終了後の 300ms 遅延発火が別テスト実行中に漏れうる（`applyReplacementRulesNowReplacesText` のクラッシュはこの巻き込みとみられる）
  - 対応: action 送信をクロージャ注入にしてテストで差し替える。`llm-wiki/testing.md` は既にこのパターンを規定しているが、現行コードに差し替え口がなく wiki と乖離している（コード修正後に wiki を再編纂）
  - ClipboardPasterTests の `clipboardPasterCallsSimulatePaste` / `clipboardPasterSimulatePasteErrorPropagates` が CLI（`swift test`）実行で `.targetAppTerminated` になるのは別件の環境依存。同時に整理する
- [ ] enum → 表示文字列変換の全ケーステストを追加する
  - `VoiceInputCoordinator.swift:291-321` `displayMessage`（エラー・ステータスとも 1 ケースのみ検証済み）、`InputPanelController.swift:459-473` `errorMessage`（ClipboardPasterError 残 2 ケース + default 未検証）、`HotkeyKeyChoice.swift:15-57` `allChoices` / `displayName`、`InputPanelToolbar.swift:130-140` `modifierBadge`
- [ ] VoiceInputCoordinator の重複除去ロジックを直接テストする
  - `stripOverlappingPrefix`（`VoiceInputCoordinator.swift:361-375`）と `stripLeadingDuplicatePunctuation`（377-388）は private 純関数で、InputPanelControllerReplayTests 経由の間接カバレッジのみ
  - 境界値（`maxSuffixLen` 512 制限、suffixLen == 1 の句読点判定分岐）が未検証。internal 化または型抽出で直接単体テストする

## v1.7.0 — 純ロジック抽出（軽量）

- [ ] View 埋め込みの純ロジックを抽出してテストし、派生コレクションを再計算からキャッシュに変える
  - `ReplacementRuleManagementView.swift:18` `duplicatePatterns`（`[ReplacementRule] → Set<String>` の純関数）、`HistoryView.swift:12` `filteredEntries`、`InputLevelMeter.swift:25` `levelColor` を抽出してテストする
  - `filteredEntries` は検索や履歴と無関係な再描画（コピー表示の 1.5 秒アニメーション等）でも全件 filter が走る。`searchText` / `entries` 変更時のみ再計算する形にする。`duplicatePatterns` も同じパターンなので抽出とキャッシュ化を同時に行う
- [ ] SpeechLocale を KoechoCore へ移動し、SpeechModelVerificationCache と合わせて直接テストする
  - `SpeechLocale.swift:8-21` は Foundation のみの純関数だが KoechoPlatform に配置。`SpeechModelVerificationCache.swift:12-29` は純粋な Set 状態管理。どちらも直接テストがない
- [ ] AudioInputLevelMonitor のレベル計算を純関数に抽出してテストする
  - `AudioInputLevelMonitor.swift:297-315` の RMS 累積 → dB 変換 → 0...1 正規化と 50ms throttle 判定が C 関数ポインタ型の `AURenderCallback` 内にハードコードされ、外部から差し替え不可能
  - 数式部分（サンプル列 → level）を static 純関数に切り出せば KoechoPlatformTests で直接検証できる

## v1.8.0 — OS 依存層の注入点整備

- [ ] AudioDeviceManager のフォールバック規則をテスト可能にする
  - UID 解決失敗 → システムデフォルトへのフォールバック（`AudioDeviceManager.swift:91-121`）、volumeElement の main → element 1 選択（180-187）、volume clamp（134）が CoreAudio 呼び出しと混在
  - `AudioDeviceListing` が static enum 直呼びで注入不可。protocol 化（または関数注入）で分離する（方式は実装時に design-decision で判断）
- [ ] SpeechAnalyzerEngine の純ロジックを分離してテストする
  - マイク権限の switch（`SpeechAnalyzerEngine.swift:109-126`）、SpeechModelVerificationCache による検証済み判定（139-157）、デバイス UID 解決失敗時フォールバック（163-182）が AVFoundation / Speech API 呼び出しと同一メソッドに密結合
  - `waitWithTimeout`（379-397）は Speech 非依存の汎用ロジックで、現状のままテスト追加可能
  - `restartTranscriberIfNeeded()`（`VoiceInputCoordinator.swift:336-359`）も `SpeechAnalyzerEngine` 具体型へのダウンキャストのため Mock で分岐に到達できない。protocol 化すれば App 側の分岐もテストできる

## v1.9.0 — UI モデル変更

- [ ] ReplacementRuleEditView の patterns ForEach を index 識別から安定 ID 識別に変える
  - `ReplacementRuleEditView.swift:52` の `ForEach(rule.patterns.indices, id: \.self)` が index を identity にしている（Apple ガイドのアンチパターン）
  - 途中のパターンを削除すると以降の行の identity がずれ、編集中 TextField のフォーカス・状態リセットや挿入/削除アニメーションの崩れにつながる
  - 方式は未確定（ユーザー確認待ち）: A. モデル変更（patterns の要素を ID 付き型にする。decode 時に ID を生成すれば保存フォーマットは不変。推奨） / B. ビュー側で ID 付きラッパー配列を管理（KoechoCore 不変だが双方向同期がバグ源になりやすい）

## v1.x.0 以降（時期未定）

- [ ] ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー decode フォールバック）を撤去する
  - v1.4.0 で patterns 複数化と同時に導入。v1.3.0 以前からの直接更新で置換ルールが decode 失敗→全損するのを防ぐための移行コード
  - 2026-06-11 ユーザー判断: v1.4.x / v1.5.x の移行期間を確保し、v1.6 以降で撤去する（条件は v1.6.0 リリース時点で満たされるため前倒し可）
- [ ] （削除提案中・ユーザー確認待ち）InputPanelScriptStrip にスクリプトの drag-to-reorder を追加する
  - macOS 27 の `.reorderable()` + `.reorderContainer(for:)` で List 以外（横 ScrollView の HStack）でも並び替えが可能になった。設定画面を開かずに入力パネル上でスクリプト順を変えられる
  - デプロイターゲットが macOS 14 のため `if #available(macOS 27, *)` ガードが必要
  - 削除提案の理由: 頻度の低い操作のために macOS 27 限定の分岐を抱える価値が薄く、設定画面の onMove で既に並び替え可能。採用する場合のみ、管理画面 List の `onMove`（`ReplacementRuleManagementView.swift:52` / `ScriptManagementView.swift:24`）を `reorderable` に揃えるかも同時に判断する

## SDK 更新時（バージョン非依存）

- [ ] Xcode 27 SDK でのビルド互換を確認する
  - SDK 27 で `@State` が property wrapper からマクロに移行。問題になる 3 パターン（init 内で `@State` より後の stored property に代入・property wrapper の合成・extension での memberwise init 委譲）は現状のコードに該当なしと確認済みだが、SDK 更新時にビルドして確認する
  - `@ContentBuilder` への result builder 統一で overlay/background の ShapeStyle オーバーロードが曖昧になるケースあり。エラーが出たら swiftui-whats-new-27 skill の references を参照して直す（自力で推測しない）

## レビュー記録（対応不要と判断したもの）

- SwiftUI レビュー（2026-07-02 swiftui-specialist skill）で確認済み・対応不要: `@Observable` + `@Bindable` 統一、新 `onChange` シグネチャ、`Identifiable` な List/ForEach、unary な行ビュー、ローカライズ（カタログ登録済み）はいずれも問題なし。NavigationView / AnyView / ObservableObject 等の soft-deprecated API の使用もなし
- macOS 27 レビュー（2026-07-02 swiftui-whats-new-27 skill）で該当なし: AsyncImage（不使用）、alert/confirmationDialog の item binding（alert 不使用）、swipeActions の非 List 対応（List のみ使用）、新 toolbar API（対象になる toolbar がほぼない）、ReadableDocument/WritableDocument（ドキュメントベースアプリではない）
- テストカバレッジ調査（2026-07-03 実測: App target 42.3% / KoechoCore 91〜100% / KoechoPlatform は OS 依存層に空白）。方針: テスト数を増やすのではなく「OS 依存コードに混ざった純ロジックの抽出・注入点の追加」でテスト可能な形に直す（上の v1.6.0〜v1.8.0 に割り振り済み）
  - KoechoCore は初期値・永続化・migration・エッジケースまで網羅済みで追加余地が小さい
  - 設定系 SwiftUI View の 0%（GeneralSettingsView / VoiceInputSection / HistoryView 等）は View 宣言主体で、ロジックは委譲先の型が持つ。View の行カバレッジ自体は追わない
  - LiveAccessibilityClient / LiveCGEventClient / AccessibilityTrust は OS API の薄いラッパーで protocol 境界の外側。消費者側（SelectedTextReader / ClipboardPaster）は Mock 注入でテスト済み
