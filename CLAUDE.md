# CLAUDE.md

この project の指示の正本は `AGENTS.md`。作業開始時に読み、以降はその入口と参照先に従う。

## プロジェクト概要

Koecho は macOS 14.0+ 向けの軽量音声入力アプリ。詳細: docs/rules/mission.md

## docs/rules/

計画・実装時に必ず Read で参照すること。CLAUDE.md の要約で済ませず、実ファイルを読んで判断する。

- プロダクト目的・非目標: docs/rules/mission.md
- コード規約・テスト方針・言語: docs/rules/principles.md
- 技術スタック・前提条件: docs/rules/constraints.md
- 機能スコープ: docs/rules/scope.md
- モジュール構成・依存方向: docs/rules/architecture.md
- Xcode 操作（ビルド・テスト・Preview・ドキュメント検索）: docs/rules/xcode-mcp.md
- 変更時の検証方法と必須 gate: docs/rules/verification.md
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

## Constraints / ドキュメント管理

- 同じ情報を複数のドキュメントに書かない。各情報の置き場所は1箇所に限定する（DRY / SSoT は `docs/rules/information-management.md` 参照）
- 新しいスキルやファイルを作成したら、同じステップで `.claude/settings.json` 等への登録も行う
- 技術的知見は「特定ソースの罠 → そのソースのコメント / 横断的な挙動・設計理解 → `llm-wiki/` の地図」へ分配し、単一の集約ファイルは作らない
