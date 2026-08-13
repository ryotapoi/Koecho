# Koecho

Koecho は macOS 14.0+ 向けの軽量音声入力アプリ。詳細は `docs/rules/mission.md` を正とする。

## Information Sources

- `docs/rules/`: プロダクト目的、スコープ、アーキテクチャ、制約、検証、Xcode 操作、情報管理
- `docs/specs/`: 振る舞い仕様。現状は未配置だが、テストだけでは意図が残らない仕様が増えたら追加する
- `backlog/backlog.md`: 未着手・進行中の作業項目
- `docs/decisions/`: 後から理由を問われる判断
- `llm-wiki/`: AI が編纂・保守する作業地図（正本ではない）

必要な情報だけ読む。全ファイルを毎回読む必要はない。ただし判断に影響する可能性がある情報源は、推測で済ませず実物を確認する。

変更時の検証方法と必須gateは `docs/rules/verification.md` を正本とする。

## Core Policies

- workflow / skill は ICAR（Intent / Constraints / Acceptance / Relevant）を基本形にする。細かい手順や長い観点は、必要に応じて workflow 内の phase ICAR、別 md、`llm-wiki/` へ逃がす。
- 小さい変更に重い手続きを載せない。作業の大きさとリスクで plan / verify / review の深さを選ぶ。
- 原則 1 plan = 1 commit。独立した成果が混ざるなら plan を分ける。
- 理想は全体が綺麗な状態だが、各 plan では今回の変更範囲と直接の依存先/依存元を中心に見る。広い構造改善は必要に応じて `backlog/backlog.md` へ切り出すか、グローバル `maintenance-audit` skill をユーザー起点で使う。
- 不明点が仕様、UX、データ保持、削除方針に影響するならユーザーに確認する。
- 仕様変更は `docs/rules/`、`docs/specs/`、`backlog/backlog.md` の適切な場所に同期する。`docs/specs/` とテストが矛盾したら、現在の要求・`docs/rules/`・`docs/decisions/` と照合して古い方を直す。
- 技術的知見は「特定ソースの罠 → そのソースのコメント / 横断的な挙動・設計理解 → `llm-wiki/` の地図」へ分配し、単一の集約ファイルは作らない。
- 後から制約になる判断は `docs/decisions/` に残す。

## Skills

`AGENTS.md` ではスキルの場所や一覧を管理しない。

SwiftUI View 層を変更するときは `swiftui-specialist` を使う。

独立した調査・レビュー・実装は subagent で並列化してよい。subagent に依頼するときは、作業ディレクトリ `/Users/ryota/Sources/ryotapoi/Koecho` を明記する。

## Koecho Constraints

- SwiftUI + Model/Service パターンを基本とし、AppState が中核状態を保持し、ロジックは Services に分離する。
- `Koecho → KoechoPlatform → KoechoCore` の一方向依存を守る。KoechoCore に macOS 固有 API（AppKit, Carbon, CoreAudio 等）を import しない。
- NSTextView 依存のコード（DictationEngine 等）を App target の外に漏らさない。
- ディクテーション制御・テキストコミットのライフサイクル、volatile テキスト、`isSuppressingCallbacks`、NSTextView / textStorage の直接操作は High-risk として扱う。
- UserDefaults の永続化パターン変更・設定マイグレーション、権限依存機能（Accessibility / Input Monitoring）、CGEvent ペースト、グローバルホットキー（NSEvent）、外部スクリプト実行（Process + Pipe）、並行性（@MainActor 境界、async/await、AVAudioEngine コールバック）は High-risk として扱う。
- 後方互換性のためだけの shim / deprecated / fallback 分岐を追加しない。
- `--no-verify` でフックをスキップしない。
- 明示的な指示なしに force push しない。

## Language

- コード・コメント・コミットメッセージ: 英語
- ドキュメント（`AGENTS.md`, `.agents/`, `docs/rules/`, `docs/specs/`, `backlog/`, `docs/decisions/`, `llm-wiki/`, README 等）: 日本語
