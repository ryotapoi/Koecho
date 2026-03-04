# CLAUDE.md

## プロジェクト概要

Koecho は macOS 14.0+ 向けの軽量音声入力ラッパーアプリ。詳細: rules/mission.md

## rules/

rules/ に定義。実装時に参照すること。

- プロダクト目的・非目標: rules/mission.md
- コード規約・テスト方針・言語: rules/principles.md
- 技術スタック・前提条件: rules/constraints.md
- 機能スコープ: rules/scope.md

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

詳細仕様: rules/scope.md

## 開発ワークフロー

IMPORTANT: 以下のフローを必ずこの順番で実行すること。ステップを飛ばしてはならない。

### Step 1: 計画（プランモード）

EnterPlanMode でプランを作成する。

### Step 2: プランレビュー

プランの記述が完了したら、**ExitPlanMode を直接呼んではならない**。
必ず先に `/review-plan-all` スキルを Skill ツールで実行する。
レビュー完了後に ExitPlanMode を呼ぶ。

### Step 3: 実装

プラン承認後、`rules/` と `references/knowledge.md` を事前確認してから実装・テストを行う。

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

## ドキュメント管理

- 同じ情報を複数のドキュメントに書かない。各情報の置き場所は1箇所に限定する
- 新しいスキルやファイルを作成したら、同じステップで settings.json 等への登録も行う

### フォルダ構成

| ディレクトリ | 役割 |
|---|---|
| `rules/` | 方針・スコープ・拘束的制約（mission / scope / constraints / principles） |
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

