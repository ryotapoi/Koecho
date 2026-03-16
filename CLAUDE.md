# CLAUDE.md

## プロジェクト概要

Koecho は macOS 14.0+ 向けの軽量音声入力アプリ。詳細: rules/mission.md

## rules/

計画・実装時に必ず Read で参照すること。CLAUDE.md の要約で済ませず、実ファイルを読んで判断する。

- プロダクト目的・非目標: rules/mission.md
- コード規約・テスト方針・言語: rules/principles.md
- 技術スタック・前提条件: rules/constraints.md
- 機能スコープ: rules/scope.md
- モジュール構成・依存方向: rules/architecture.md
- 開発ワークフロー: rules/workflow.md
- Xcode 操作（ビルド・テスト・ドキュメント検索）: rules/xcode-mcp.md
- 情報管理の原則（フォルダ構成・情報分類・SSoT）: rules/information-management.md

## 開発ワークフロー

IMPORTANT: 各ステップの詳細は rules/workflow.md に定義。ステップに入る前に該当セクションを Read で読むこと。

1. **計画** — rules/workflow.md「Step 1: 計画」を読んでから着手
2. **プランレビュー** — rules/workflow.md「Step 2: プランレビュー」に従う
3. **実装** — rules/workflow.md「Step 3: 実装」を読んでから着手
4. **実装レビュー** — rules/workflow.md「Step 4: 実装レビュー」に従う
5. **コミット** — rules/workflow.md「Step 5: コミット」に従う

## ドキュメント管理

新しいスキルやファイルを作成したら、同じステップで settings.json 等への登録も行う。

## デバッグ

バグ修正・デバッグ時は `/debug` スキルを使う。
