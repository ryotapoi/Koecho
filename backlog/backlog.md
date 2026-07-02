# Backlog

## v1.5.0

- [x] AppIcon を変更する
- [x] AppIcon 切り替え機能を追加する
- [x] アプリデザインをブラッシュアップする

## v1.6 以降

- [ ] ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー decode フォールバック）を撤去する
  - v1.4.0 で patterns 複数化と同時に導入。v1.3.0 以前からの直接更新で置換ルールが decode 失敗→全損するのを防ぐための移行コード
  - 2026-06-11 ユーザー判断: v1.4.x / v1.5.x の移行期間を確保し、v1.6 以降で撤去する

### SwiftUI リファクタリング候補（2026-07-02 swiftui-specialist skill でレビュー）

- [ ] ReplacementRuleEditView の patterns ForEach を index 識別から安定 ID 識別に変える
  - `ReplacementRuleEditView.swift:52` の `ForEach(rule.patterns.indices, id: \.self)` が index を identity にしている（Apple ガイドのアンチパターン）
  - 途中のパターンを削除すると以降の行の identity がずれ、編集中 TextField のフォーカス・状態リセットや挿入/削除アニメーションの崩れにつながる
  - 対応案: patterns の要素に安定 ID を持たせる（`ReplacementRule` のモデル変更を伴うため decode 互換に注意）か、ビュー側で ID 付きラッパー配列を管理する
- [ ] body 評価ごとに再計算している派生コレクションをキャッシュする
  - `HistoryView.swift:12` `filteredEntries`: 検索や履歴と無関係な再描画（コピー表示の 1.5 秒アニメーション等）でも全件 filter が走る。`searchText` / `entries` 変更時のみ再計算する形にする
  - `ReplacementRuleManagementView.swift:18` `duplicatePatterns`: 同じパターン。ルール数が少ないうちは実害は小さいが同時に直す
- 確認済み・対応不要: `@Observable` + `@Bindable` 統一、新 `onChange` シグネチャ、`Identifiable` な List/ForEach、unary な行ビュー、ローカライズ（カタログ登録済み）はいずれも問題なし。NavigationView / AnyView / ObservableObject 等の soft-deprecated API の使用もなし

### macOS 27 / Xcode 27 向け候補（2026-07-02 swiftui-whats-new-27 skill でレビュー）

- [ ] Xcode 27 SDK でのビルド互換を確認する
  - SDK 27 で `@State` が property wrapper からマクロに移行。問題になる 3 パターン（init 内で `@State` より後の stored property に代入・property wrapper の合成・extension での memberwise init 委譲）は現状のコードに該当なしと確認済みだが、SDK 更新時にビルドして確認する
  - `@ContentBuilder` への result builder 統一で overlay/background の ShapeStyle オーバーロードが曖昧になるケースあり。エラーが出たら swiftui-whats-new-27 skill の references を参照して直す（自力で推測しない）
- [ ] InputPanelScriptStrip にスクリプトの drag-to-reorder を追加する
  - macOS 27 の `.reorderable()` + `.reorderContainer(for:)` で List 以外（横 ScrollView の HStack）でも並び替えが可能になった。設定画面を開かずに入力パネル上でスクリプト順を変えられる
  - デプロイターゲットが macOS 14 のため `if #available(macOS 27, *)` ガードが必要
- [ ] 管理画面 List の `onMove` を `reorderable` に揃えるか判断する
  - `ReplacementRuleManagementView.swift:52` / `ScriptManagementView.swift:24`。`onMove` は引き続き動作し移行必須ではない。上の script strip 対応で reorderable を導入するなら書き方を揃える程度の位置づけ
- 該当なし: AsyncImage（不使用）、alert/confirmationDialog の item binding（alert 不使用）、swipeActions の非 List 対応（List のみ使用）、新 toolbar API（対象になる toolbar がほぼない）、ReadableDocument/WritableDocument（ドキュメントベースアプリではない）

### テストカバレッジ改善候補（2026-07-03 カバレッジ実測 + 調査）

実測: App target 42.3% / KoechoCore 91〜100% / KoechoPlatform は OS 依存層に空白（SpeechAnalyzerEngine 9.9%、AudioInputLevelMonitor 5.6%、AudioDeviceManager 30.3%、AccessibilityClient・SpeechModelVerificationCache 0% 等）。
方針: テスト数を増やすのではなく「OS 依存コードに混ざった純ロジックの抽出・注入点の追加」でテスト可能な形に直す。

コード改善でテスト可能になるもの:

- [ ] AudioInputLevelMonitor のレベル計算を純関数に抽出してテストする
  - `AudioInputLevelMonitor.swift:297-315` の RMS 累積 → dB 変換 → 0...1 正規化と 50ms throttle 判定が C 関数ポインタ型の `AURenderCallback` 内にハードコードされ、外部から差し替え不可能
  - 数式部分（サンプル列 → level）を static 純関数に切り出せば KoechoPlatformTests で直接検証できる
- [ ] SpeechAnalyzerEngine の純ロジックを分離してテストする
  - マイク権限の switch（`SpeechAnalyzerEngine.swift:109-126`）、SpeechModelVerificationCache による検証済み判定（139-157）、デバイス UID 解決失敗時フォールバック（163-182）が AVFoundation / Speech API 呼び出しと同一メソッドに密結合
  - `waitWithTimeout`（379-397）は Speech 非依存の汎用ロジックで、現状のままテスト追加可能
  - `restartTranscriberIfNeeded()`（`VoiceInputCoordinator.swift:336-359`）も `SpeechAnalyzerEngine` 具体型へのダウンキャストのため Mock で分岐に到達できない。protocol 化すれば App 側の分岐もテストできる
- [ ] VoiceInputCoordinator の重複除去ロジックを直接テストする
  - `stripOverlappingPrefix`（`VoiceInputCoordinator.swift:361-375`）と `stripLeadingDuplicatePunctuation`（377-388）は private 純関数で、InputPanelControllerReplayTests 経由の間接カバレッジのみ
  - 境界値（`maxSuffixLen` 512 制限、suffixLen == 1 の句読点判定分岐）が未検証。internal 化または型抽出で直接単体テストする
- [ ] AudioDeviceManager のフォールバック規則をテスト可能にする
  - UID 解決失敗 → システムデフォルトへのフォールバック（`AudioDeviceManager.swift:91-121`）、volumeElement の main → element 1 選択（180-187）、volume clamp（134）が CoreAudio 呼び出しと混在
  - `AudioDeviceListing` が static enum 直呼びで注入不可。protocol 化（または関数注入)で分離する
- [ ] View 埋め込みの純ロジックを抽出してテストする
  - `ReplacementRuleManagementView.swift:18` `duplicatePatterns`（`[ReplacementRule] → Set<String>` の純関数）、`HistoryView.swift:12` `filteredEntries`、`InputLevelMeter.swift:25` `levelColor`
  - 上の「派生コレクションをキャッシュする」タスクと同じ箇所なので、キャッシュ化と抽出を同時に行う
- [ ] SpeechLocale を KoechoCore へ移動し、SpeechModelVerificationCache と合わせて直接テストする
  - `SpeechLocale.swift:8-21` は Foundation のみの純関数だが KoechoPlatform に配置。`SpeechModelVerificationCache.swift:12-29` は純粋な Set 状態管理。どちらも直接テストがない

コード改善なしで追加できるもの（小粒、まとめて 1 commit 程度）:

- [ ] enum → 表示文字列変換の全ケーステストを追加する
  - `VoiceInputCoordinator.swift:291-321` `displayMessage`（エラー・ステータスとも 1 ケースのみ検証済み）、`InputPanelController.swift:459-473` `errorMessage`（ClipboardPasterError 残 2 ケース + default 未検証）、`HotkeyKeyChoice.swift:15-57` `allChoices` / `displayName`、`InputPanelToolbar.swift:130-140` `modifierBadge`

テスト健全性:

- [ ] DictationEngine の startDictation 実送信をクロージャ注入にして flaky クラッシュを直す
  - 2026-07-03 に全 189 件実行で `applyReplacementRulesNowReplacesText` と `stopFromListeningTransitions` が「Crash: Koecho at \<external symbol\>」で失敗（単独再実行では成功）。クラッシュレポートで原因特定済み: `DictationEngine.sendStartDictation()`（`DictationEngine.swift:75`）が実の `NSApp.sendAction(startDictation:)` を送信し、HIToolbox / TSM 内で SIGSEGV（KERN_INVALID_ADDRESS）
  - `stopFromListeningTransitions` は 400ms 待つため実送信に到達する（`DictationEngineTests.swift:72`）。また `start()` の retryTask はクロージャが engine を強参照し、InputPanel も NSApp が保持するため、テスト終了後の 300ms 遅延発火が別テスト実行中に漏れうる（`applyReplacementRulesNowReplacesText` のクラッシュはこの巻き込みとみられる）
  - 対応: action 送信をクロージャ注入にしてテストで差し替える。`llm-wiki/testing.md` は既にこのパターンを規定しているが、現行コードに差し替え口がなく wiki と乖離している（コード修正後に wiki を再編纂）
  - ClipboardPasterTests の `clipboardPasterCallsSimulatePaste` / `clipboardPasterSimulatePasteErrorPropagates` が CLI（`swift test`）実行で `.targetAppTerminated` になるのは別件の環境依存。同時に整理する

対応不要と判断したもの:

- KoechoCore は初期値・永続化・migration・エッジケースまで網羅済みで追加余地が小さい
- 設定系 SwiftUI View の 0%（GeneralSettingsView / VoiceInputSection / HistoryView 等）は View 宣言主体で、ロジックは委譲先の型が持つ。View の行カバレッジ自体は追わない
- LiveAccessibilityClient / LiveCGEventClient / AccessibilityTrust は OS API の薄いラッパーで protocol 境界の外側。消費者側（SelectedTextReader / ClipboardPaster）は Mock 注入でテスト済み
