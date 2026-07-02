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
