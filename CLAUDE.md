# CLAUDE.md

## プロジェクト概要

Koecho（こえこ / Ko-echo）はmacOS 14.0+向けの軽量音声入力ラッパーアプリ。
macOS標準のDictation機能を利用し、フローティングウィンドウで音声テキストを受け取り、
シェルスクリプトで加工してフォアグラウンドアプリにペーストする。

読み: こえこ / Ko-echo
由来: Koe（声）+ chotto（ちょっと）。echo（反響）の意味も掛かっている。

## MCP ツール使い分け

2つの MCP サーバーを併用する。Bash で `xcodebuild` を直接叩かない。

### XcodeBuildMCP（優先）

ビルド・テストはすべて XcodeBuildMCP のツールを使う。
構造化レスポンスでエラーがファイル名・行番号付きで返るため、生ログのパースが不要。

- ビルド: `build_macos`
- テスト: `test_macos`（`-only-testing:KoechoTests` で UITests を除外）

### Apple Xcode MCP（補助）

Xcode の内部状態にアクセスする必要があるときに使う（Xcode 起動が必要）。

- Apple ドキュメント検索: `DocumentationSearch`（WebSearch より優先）
- Swift REPL 実行: `ExecuteSnippet`（Bash の `swift` より優先）
- SwiftUI プレビュー: `RenderPreview`
- ライブ診断: `XcodeRefreshCodeIssuesInFile`

## ビルド・テスト

テストはSwift Testing（@Test マクロ）。テストファイルは KoechoTests/ 配下。

## アーキテクチャ

ユーザー音声 → macOS Dictation → TextEditor (InputPanel)
  → スクリプト実行（その場でテキスト置換、何度でも可）
  → ホットキー再押下で確定 → ClipboardPaster (CGEvent Cmd+V) → フォアグラウンドアプリ

詳細仕様: rules/spec.md

## コード規約

- SwiftUI + Model/Service パターン（AppState が中核状態を保持、ロジックは Services に分離）
- @MainActor でUIスレッド安全性を確保
- async/await ベースの非同期処理
- ロギングは os.Logger（サブシステム: com.ryotapoi.koecho）
- UserDefaults で設定保存（SwiftData 不使用）
- エラーは用途別のカスタム enum
- 後方互換性は維持しない。旧シンボルのリネーム保持・re-export・deprecated コメント・旧フォーマットへのフォールバック分岐は入れない。互換性維持が必要な場合はユーザーが明示する

## 技術スタック

- Swift / SwiftUI / macOS 14.0+
- NSPanel（フローティングウィンドウ）
- NSEvent（グローバルホットキー）
- Process + Pipe（シェルスクリプト実行）
- CGEvent（ペースト）
- Accessibility API（選択テキスト取得）
- MenuBarExtra（メニューバー常駐）
- UserDefaults（設定保存）
- os.Logger（ロギング）
- Speech framework / SpeechAnalyzer（macOS 26+ オンデバイス音声認識）
- AVAudioEngine（マイク入力取得）

## 前提条件

- App Sandbox は無効（CGEvent / Process / グローバルホットキー / Accessibility API のため）
- アクセシビリティ権限が必要（ペースト・選択テキスト取得）
- Input Monitoring 権限が必要（NSEvent.addGlobalMonitorForEvents）。macOS バージョンによりアクセシビリティ権限と別途必要になるケースがある
- macOS Dictation がユーザーにより有効化されている必要がある（無効の場合はキーボード入力のみ）
- Mac App Store 配布は対象外

## テスト方針

- ScriptRunner: タイムアウト / 空出力 / 非ゼロ終了のフォールバック
- ClipboardPaster: ペースト後のクリップボード復元
- SelectedTextReader: 権限なし・選択なし時の失敗ハンドリング

## 開発ワークフロー

IMPORTANT: 以下のフローを必ずこの順番で実行すること。ステップを飛ばしてはならない。

### Step 1: 計画（プランモード）

EnterPlanMode でプランを作成する。

### Step 2: プランレビュー

プランの記述が完了したら、**ExitPlanMode を直接呼んではならない**。
必ず先に `/review-plan-all` スキルを Skill ツールで実行する。
レビュー完了後に ExitPlanMode を呼ぶ。

### Step 3: 実装

プラン承認後、`references/knowledge.md` を事前確認してから実装・テストを行う。

### Step 4: 実装レビュー

実装・テストが完了したら、**コミットしてはならない**。
必ず先に `/review-code-all` スキルを Skill ツールで実行する。

### Step 5: コミット

レビュー完了後、`/commit` スキルでコミットする。

### Codex 指摘の蓄積

`/review-plan-codex` や `/review-code-codex` で MUST / SHOULD の指摘が出たら、`tmp/codex-findings.md` に追記する。

追記形式:
```
## <セッションで何を実装したかの1行要約>
- [plan|impl] 🔴/🟡 <指摘内容の要約>
  - self で防げたか: Yes/No
  - スコープ: project / common
  - 詳細: <具体的な指摘を1-2行で>
```

20〜30件溜まったら一括分類し、skill への反映を検討する。

## 言語

コミットメッセージは英語（Conventional Commits）。ドキュメントは日本語の場合がある。コード（変数名、コメント）は英語で書く。

## ドキュメント管理

- 同じ情報を複数のドキュメントに書かない。各情報の置き場所は1箇所に限定する
- 新しいスキルやファイルを作成したら、同じステップで settings.json 等への登録も行う

### フォルダ構成

| ディレクトリ | 役割 |
|---|---|
| `rules/` | 方針・スコープ・拘束的制約（spec.md） |
| `decisions/` | 意思決定ログ（ADR） |
| `references/` | 実装判断に影響する補助情報（knowledge.md） |
| `backlog/plans/` | 実装計画ファイル（gitignore 対象、/simplify が diff で参照） |
| `CLAUDE.md` | 常に意識すべきルール・制約（毎回読み込まれる） |

技術的な知見・ハマりどころは以下の基準で振り分ける:

- **CLAUDE.md**: 常に意識すべきルール・制約（毎回読み込まれる）
- **references/knowledge.md**: 特定の状況で役立つ知見（該当する実装のときに読みに行く）

実装前やバグ調査時は `references/knowledge.md` を確認すること。

## デバッグ

バグ修正・デバッグ時は `/debug` スキルを使う。

