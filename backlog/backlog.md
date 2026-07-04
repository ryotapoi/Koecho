# Backlog

## v1.6.3 — UI モデル変更

- [x] ReplacementRuleEditView の patterns ForEach を index 識別から安定 ID 識別に変える
  - `ReplacementRuleEditView.swift:52` の `ForEach(rule.patterns.indices, id: \.self)` が index を identity にしている（Apple ガイドのアンチパターン）
  - 途中のパターンを削除すると以降の行の identity がずれ、編集中 TextField のフォーカス・状態リセットや挿入/削除アニメーションの崩れにつながる
  - 方式確定（2026-07-03 design-decision）: モデル変更。patterns の要素を ID 付き型にする（行 identity は編集 UI に既に存在する意味で、型で表す）。encode/decode は `[String]` のまま維持し decode 時に ID 生成（保存フォーマット不変、永続 ID は現在の要求にないため足さない）
  - 実装時の注意: `ReplacementRule` は `Equatable` のため、ID を比較に含めるか（内容が同じでも ID 違いで不等になる）は実装時に既存テスト・利用箇所を見て決める

## v1.x.0 以降（時期未定）

- [ ] ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー decode フォールバック）を撤去する
  - v1.4.0 で patterns 複数化と同時に導入。v1.3.0 以前からの直接更新で置換ルールが decode 失敗→全損するのを防ぐための移行コード
  - 2026-06-11 ユーザー判断: v1.4.x / v1.5.x の移行期間を確保し、v1.6 以降で撤去する（条件は v1.6.0 リリース時点で満たされるため前倒し可）
- [ ] InputPanelScriptStrip にスクリプトの drag-to-reorder を追加する
  - macOS 27 の `.reorderable()` + `.reorderContainer(for:)` で List 以外（横 ScrollView の HStack）でも並び替えが可能になった。機能自体は増えず「どこでできるか」が変わる: 設定画面を開かずに入力パネル上でスクリプト順を変えられる
  - デプロイターゲット macOS 14 のままなら `if #available(macOS 27, *)` ガードが必要。deployment target を上げた後にやれば分岐なしで書ける
  - 実装する時に、管理画面 List の `onMove`（`ReplacementRuleManagementView.swift:52` / `ScriptManagementView.swift:24`）を `reorderable` に揃えるかも同時に判断する

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
