# Koecho

Koecho は macOS 27.0+ 向けの軽量音声入力アプリ。詳細は `docs/rules/mission.md` を正とする。

## タスク別の正本

タスクに必要な文書だけを読む。推測で済ませず、判断に影響する正本を確認する。

- 目的・非目標・対象範囲・ユーザー挙動: `docs/rules/mission.md`、`docs/rules/scope.md`、`docs/specs/`
- 責務配置・依存方向: `docs/rules/architecture.md`
- 技術制約・実装原則: `docs/rules/constraints.md`、`docs/rules/principles.md`
- 検証の必須 gate: `docs/rules/verification.md`
- Xcode 操作: `docs/rules/xcode-mcp.md`
- docs・backlog・llm-wiki の変更: `docs/rules/information-management.md`
- 過去の判断理由: `docs/decisions/`
- リリース: `docs/rules/release.md`

## 変更時の注意

- SwiftUI View 層を変更するときは `swiftui-specialist` を使う。
- ディクテーション制御・テキストコミットのライフサイクル、volatile テキスト、`isSuppressingCallbacks`、NSTextView / textStorage の直接操作は High-risk として扱い、`docs/rules/verification.md` を確認する。
- UserDefaults の永続化パターン変更・設定マイグレーション、権限依存機能（Accessibility / Input Monitoring）、CGEvent ペースト、グローバルホットキー（NSEvent）、外部スクリプト実行（Process + Pipe）、並行性（`@MainActor` 境界、async/await、AVAudioEngine コールバック）は High-risk として扱い、`docs/rules/verification.md` を確認する。
- `--no-verify` でフックをスキップしない。
- 明示的な指示なしに force push しない。

## Language

コード・コメント・コミットメッセージは英語、ドキュメント（`AGENTS.md`、`.agents/`、`docs/rules/`、`docs/specs/`、`backlog/`、`docs/decisions/`、`llm-wiki/`、README 等）は日本語とする。
