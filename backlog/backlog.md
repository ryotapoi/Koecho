# Backlog

- [ ] HistoryStore のディレクトリ名リテラルを専用定数にする
  - `HistoryStore.swift:18` の `"com.ryotapoi.koecho"` は Logger subsystem 定数と同値だが別目的で、Bundle ID（`com.ryotapoi.Koecho`、K 大文字）とも食い違う。「変更すると既存ユーザーの履歴保存先が変わりデータ移行が必要」を定数名 or コメントで明示する（値は変えない）
- [ ] ShortcutKeyRecorder のキーイベント処理から純ロジックを抽出してテストする
  - `handleKeyEvent` 相当の判定ロジックが OS イベント依存のまま未テスト。既存のテスト方針（OS 依存コードに混ざった純ロジックの抽出・注入点の追加）に沿って抽出 + unit test（2026-07-09 Codex audit）

## ドキュメント整合（バージョン非依存）

- [ ] ADR 0003/0011 の `appliesReplacementRulesOnConfirm` 記述を実装に同期する
  - `docs/decisions/0003-manual-trigger-for-replacement-rules.md:34` と `0011-debounced-auto-replacement.md:13` が実在しない設定を参照している（ソース grep 0 件を確認済み）。revised 注記か supersede 記録で現状に同期する（2026-07-09 audit）
- [ ] 置換ルール機能を scope.md（荒い粒度）と docs/specs/（振る舞い詳細）に書き分ける
  - 置換機能（auto-replacement と手動 Ctrl+R の意図的併存を含む）の要求定義が ADR 0003/0011/0020 に分散し、正本 scope.md からは auto-run 文脈でしか読めない（2026-07-09 audit）
  - 2026-07-09 ユーザー判断: information-management.md の共通原則に合わせる。scope.md には主要機能としての荒い節だけ追記し、振る舞い詳細（auto/手動の併存、適用タイミング等）は docs/specs/ に最初の spec ファイルとして置く
  - あわせて scope.md が現在持っている振る舞い詳細（トグル動作・環境変数表等）も、置換ルールの spec を置くタイミング以降、触る機会に specs/ へ順次移す（scope は「粒度を荒く保つ」に寄せる）

## v1.x.0 以降（時期未定）

- [ ] InputPanelScriptStrip にスクリプトの drag-to-reorder を追加する
  - macOS 27 の `.reorderable()` + `.reorderContainer(for:)` で List 以外（横 ScrollView の HStack）でも並び替えが可能になった。機能自体は増えず「どこでできるか」が変わる: 設定画面を開かずに入力パネル上でスクリプト順を変えられる
  - デプロイターゲット macOS 14 のままなら `if #available(macOS 27, *)` ガードが必要。deployment target を上げた後にやれば分岐なしで書ける
  - 実装する時に、管理画面 List の `onMove`（`ReplacementRuleManagementView.swift:52` / `ScriptManagementView.swift:24`）を `reorderable` に揃えるかも同時に判断する
- [ ] 選択した入力デバイスが解決できなかった時にパネル上でわかるようにする（必須ではない）
  - 現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）
  - 2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する

## SDK 更新時（バージョン非依存）

- [ ] Xcode 27 SDK でのビルド互換を確認する
  - SDK 27 で `@State` が property wrapper からマクロに移行。問題になる 3 パターン（init 内で `@State` より後の stored property に代入・property wrapper の合成・extension での memberwise init 委譲）は現状のコードに該当なしと確認済みだが、SDK 更新時にビルドして確認する
  - `@ContentBuilder` への result builder 統一で overlay/background の ShapeStyle オーバーロードが曖昧になるケースあり。エラーが出たら swiftui-whats-new-27 skill の references を参照して直す（自力で推測しない）

## レビュー記録（対応不要と判断したもの）

- maintenance-audit deep 比較実行（2026-07-09、Fable+sonnet 版と Codex 版の並走）で確認・不採用と判断したもの（design-decision 基準適用）:
  - `AudioObjectPropertyAddress` 構築の factory 化 — CoreAudio 定型の反復で、共通化は呼び出し側の意味をぼやけさせ読解経路を増やす方が大きい。listener の add/remove アドレス対応は smoke テスト強化（v1.6.7）で守る
  - Settings 系クラスの UserDefaults 永続化共通化（property wrapper 等）— キー・デフォルト値・クランプ規則（`max(1,...)` 等）は各クラスで別々に変わる知識。共通化できるのは配管だけで意味が薄い。Settings クラスが増えたら再検討
  - エンジン別分岐（`is DictationEngine` キャスト等）の protocol 分割 — エンジン 2 実装固定の現要求では将来の先取り。触る機会に前提コメントを明記する程度で足りる
  - error→UI message 変換の共通型化 — `errorMessage(for:)` と `scriptErrorMessage(for:script:)` は対象エラー型が別で、統合は形が似ているだけ。3 つ目の変換が必要になった時に再評価
  - AppState のサブ状態分割（PromptState / PanelState 等）— 現状約 30 行で許容。共有可変バッグ化が進んだら再評価（watch）
  - DI seam 流儀（protocol 注入 vs 生成パラメータ差し替え）の明文化 — 併存にはそれぞれ意味があり（外部 I/O 境界は protocol、値的依存はパラメータ）、実害が出ている箇所（AudioDeviceManager の注入点欠如）は v1.6.7 のテスト項目で扱う。全体流儀の明文化は迷いが実際に発生したら architecture.md へ

- SwiftUI レビュー（2026-07-02 swiftui-specialist skill）で確認済み・対応不要: `@Observable` + `@Bindable` 統一、新 `onChange` シグネチャ、`Identifiable` な List/ForEach、unary な行ビュー、ローカライズ（カタログ登録済み）はいずれも問題なし。NavigationView / AnyView / ObservableObject 等の soft-deprecated API の使用もなし
- macOS 27 レビュー（2026-07-02 swiftui-whats-new-27 skill）で該当なし: AsyncImage（不使用）、alert/confirmationDialog の item binding（alert 不使用）、swipeActions の非 List 対応（List のみ使用）、新 toolbar API（対象になる toolbar がほぼない）、ReadableDocument/WritableDocument（ドキュメントベースアプリではない）
- テストカバレッジ調査（2026-07-03 実測: App target 42.3% / KoechoCore 91〜100% / KoechoPlatform は OS 依存層に空白）。方針: テスト数を増やすのではなく「OS 依存コードに混ざった純ロジックの抽出・注入点の追加」でテスト可能な形に直す（上の v1.6.0〜v1.8.0 に割り振り済み）
  - KoechoCore は初期値・永続化・migration・エッジケースまで網羅済みで追加余地が小さい
  - 設定系 SwiftUI View の 0%（GeneralSettingsView / VoiceInputSection / HistoryView 等）は View 宣言主体で、ロジックは委譲先の型が持つ。View の行カバレッジ自体は追わない
  - LiveAccessibilityClient / LiveCGEventClient / AccessibilityTrust は OS API の薄いラッパーで protocol 境界の外側。消費者側（SelectedTextReader / ClipboardPaster）は Mock 注入でテスト済み
