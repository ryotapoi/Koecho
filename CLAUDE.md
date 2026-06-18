# CLAUDE.md

## プロジェクト概要

Koecho は macOS 14.0+ 向けの軽量音声入力アプリ。詳細: docs/rules/mission.md

## ワークフロー入口

入口は依頼の形で 2 通り。

- **Goal（`/goal` または `goal-workflow` を明示指定）**: `goal-workflow` skill を入口にする。Goal は作業全体を 1 commit 単位へ分割し、各 commit で `.claude/workflow/default.md` 以下の phase workflow を回す。Goal 手順の正本は `.claude/workflow/goal.md`。`goal-workflow` skill はそのファイルを読んで進める。Goal 前提では都度確認を避けて自動進行し、止まるのは各 workflow の Stop Conditions だけ。
- **単発依頼**: `.claude/workflow/default.md` を最初に Read し、Intake 分類（Small / Normal / High-risk / Exploratory）から必要な phase ファイルへ進む。

```text
goal-workflow skill（Goal の入口）
└── goal.md（正本: commit slicing / Goal Review / branch / ff-merge）
    └── default.md（各 commit / 単発依頼の Intake・Routing）
        ├── investigate.md — Exploratory 用の事実集め
        ├── plan.md — 計画作成（省略可条件含む。plan mode は使わない）
        ├── implement.md — 実装
        ├── verify.md — 動作確認
        ├── review.md — リスクベースの review depth 選択
        ├── finish.md — コミット + 文書同期
        └── maintenance.md — L3、節目で呼ぶ構造棚卸し
```

各 phase ファイルは入る前に Read で読む（CLAUDE.md の要約で済ませない）。
plan mode（`EnterPlanMode` / `ExitPlanMode`）は使わない。計画は内部で立ててそのまま実装する。
不明点があれば止まってユーザーに確認。なければ自動進行。
単発依頼はコミットまで終えたら止まる（次のタスクはユーザー指示待ち）。Goal は完了したら止まる。

## docs/rules/

計画・実装時に必ず Read で参照すること。CLAUDE.md の要約で済ませず、実ファイルを読んで判断する。

- プロダクト目的・非目標: docs/rules/mission.md
- コード規約・テスト方針・言語: docs/rules/principles.md
- 技術スタック・前提条件: docs/rules/constraints.md
- 機能スコープ: docs/rules/scope.md
- モジュール構成・依存方向: docs/rules/architecture.md
- Xcode 操作（ビルド・テスト・Preview・ドキュメント検索）: docs/rules/xcode-mcp.md
- 情報管理の原則（フォルダ構成・情報分類・SSoT）: docs/rules/information-management.md

## Constraints / サブエージェント活用

メインコンテキストを汚さないために、skill 以外の場面でもサブエージェントを積極的に使う。

正例（subagent に出す）:

- 結果が膨らむ・複数ファイル横断・複数キーワードでファンアウトする調査は Explore サブエージェントに委譲する
- 互いに独立した調査タスクが複数ある場合は、同一ターンで複数 subagent を並列起動する

負例（main で直接やる）:

- ファイル 1〜2 個の中身を見ればわかる調査は main で Read する
- grep 1 回で済む確認は main で Bash する
- 関連する複数 grep は 1 つの subagent でまとめる（複数 subagent に分けない）

判断軸:

- 回数ではなく「結果の量」「全体像把握が要るか」「main コンテキストを汚すか」で判断する
- 1 サブエージェント = 1 タスクに絞り、焦点を明確にする

## Constraints / ユーザー観察

見た目や挙動が絡む調査・バグ修正では、まず自力で取れる証拠（ビルド・テスト・Preview・スクリーンショット・ログ等）で確認する。
ユーザーの観察・判断なしに確定できない場合（権限ダイアログ、実際のディクテーション操作等）だけ Stop Conditions として扱い、Goal の通常進行中に都度の確認で止めない。

## Constraints / ユーザーへの質問

ユーザーに質問することになった場合は `~/.claude/resources/rules/asking-user.md` を Read してから質問を組み立てる。

## Constraints / MCP ツール使い分け

ビルド・テスト・Preview・ドキュメント検索は MCP ツールを使う。Bash で `xcodebuild` を直接叩かない。使い分けの詳細（XcodeBuildMCP / Apple Xcode MCP、`RenderPreview` のパラメータ等）は `docs/rules/xcode-mcp.md` を参照する。

## Constraints / ドキュメント管理

- 同じ情報を複数のドキュメントに書かない。各情報の置き場所は1箇所に限定する（DRY / SSoT は `docs/rules/information-management.md` 参照）
- `.claude/`・`CLAUDE.md`（Claude 側）と `.agents/`・`AGENTS.md`（Codex 側）は、目的・制約・判断基準の方向性を揃える。文言や構成の完全一致は求めず、subagent、review delegation、tool 呼び出し、skill / workflow の実行手順は各エージェントの仕組みに合わせてよい。`skills/project-risk-check/SKILL.md` は **チェック観点（Intent / Constraints / Acceptance / Checkpoints の方向性）を両側で揃える**。片方の観点を変更したら、同じコミットで他方にも反映する。
- 新しいスキルやファイルを作成したら、同じステップで `.claude/settings.json` 等への登録も行う
- 技術的知見は「特定ソースの罠 → そのソースのコメント / 横断的な挙動・設計理解 → `llm-wiki/` の地図」へ分配し、単一の集約ファイルは作らない
