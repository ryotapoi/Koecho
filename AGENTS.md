# Koecho

Koecho は macOS 14.0+ 向けの軽量音声入力アプリ。詳細は `rules/mission.md` を正とする。

## Entry Point

入口は依頼の形で 2 通り。

- **Goal（`/goal` または `goal-workflow` を明示指定）**: グローバル `goal-workflow` skill を入口にする。Goal は作業全体を 1 commit 単位へ分割し、各 commit で `.agents/workflow/default.md` 以下の phase workflow を回す。Goal 手順の正本は `.agents/workflow/goal.md`。
- **単発依頼**: 最初に `.agents/workflow/default.md` を読み、Intake から必要な phase ファイルへ進む。

各 phase に入るときだけ、対応する workflow ファイルを読む。`AGENTS.md` の要約だけで進めない。

```text
goal-workflow skill（Goal の入口）
└── .agents/workflow/goal.md（正本: commit slicing / Claude review / 完了条件）
    └── default.md（各 commit / 単発依頼の Intake・Routing）
        ├── investigate.md
        ├── plan.md
        ├── implement.md
        ├── verify.md
        ├── review.md
        ├── finish.md
        └── maintenance.md
```

Claude Code 由来の `.claude/` は参考資料として扱ってよいが、Codex の入口は `AGENTS.md` と `.agents/` に統一する。

## Information Sources

- `rules/`: プロダクト目的、スコープ、アーキテクチャ、制約、Xcode 操作、情報管理
- `specs/`: 振る舞い仕様。現状は未配置だが、テストだけでは意図が残らない仕様が増えたら追加する
- `backlog/backlog.md`: 未着手・進行中の作業項目
- `decisions/`: 後から理由を問われる判断
- `references/knowledge.md`: 技術的な知見・ハマりどころ

必要な情報だけ読む。全ファイルを毎回読む必要はない。ただし判断に影響する可能性がある情報源は、推測で済ませず実物を確認する。

## Core Policies

- workflow / skill は ICAR（Intent / Constraints / Acceptance / Relevant）を基本形にする。細かい手順や長い観点は、必要に応じて workflow 内の phase ICAR、別 md、`references/knowledge.md` へ逃がす。
- `.claude/`・`CLAUDE.md`（Claude 側）と `.agents/`・`AGENTS.md`（Codex 側）は、方針・ルールの内容を一致させる。形式は各側の流儀（`.agents/` は ICAR）に合わせてよい。`skills/koecho-risk-check/SKILL.md` は **チェック観点（Intent / Constraints / Acceptance / Checkpoints の中身）を両側一致させる**。ただし実行構造は各側の流儀でよく、Claude 側は Opus 監督 + sonnet subagent の fork 構造を持つ（Codex 側にはこの subagent 構造はない）。片方の観点を変更したら、同じコミットで他方にも反映する。
- 小さい変更に重い手続きを載せない。作業の大きさとリスクで plan / verify / review の深さを選ぶ。
- 原則 1 plan = 1 commit。独立した成果が混ざるなら plan を分ける。
- 理想は全体が綺麗な状態だが、各 plan では今回の変更範囲と直接の依存先/依存元を中心に見る。広い構造改善は必要に応じて `backlog/backlog.md` または `maintenance.md` へ切り出す。
- 不明点が仕様、UX、データ保持、削除方針に影響するならユーザーに確認する。
- 自分で確認できることは自分で確認する。ユーザー確認は、実機依存・観察が必要な挙動・ユーザーの期待出力が早い場合に限る。
- 仕様変更は `rules/`、`specs/`、`backlog/backlog.md` の適切な場所に同期する。`specs/` とテストが矛盾したら、現在の要求・`rules/`・`decisions/` と照合して古い方を直す。
- 技術的知見は `references/knowledge.md` に集約する。
- 後から制約になる判断は `decisions/` に残す。
- workflow は 1 つの commit 単位で回す。Goal が複数 commit に分かれる場合は `goal-workflow` skill に従って commit 単位へ分けて繰り返す。
- 単発依頼はコミットまで終えたら止まる（次のタスクはユーザー指示待ち）。Goal は完了したら止まる。

## Skills

Codex 用のプロジェクトスキルは `.agents/skills/` に置く。グローバルスキルは `~/.agents/skills/` に置く。Koecho ではプロジェクト内に `goal-workflow` skill を作らない。

主に使うスキル:

- `goal-workflow`: `/goal` または明示指定時だけ使う。Goal を 1 commit 単位へ分割して完了まで進める
- `design-decision`: 設計判断の価値基準を当てる
- `module-boundary`: モジュール配置、責務、依存方向を判断する
- `tdd`: 振る舞い変更や bug fix を test-first で進める
- `swiftui-pro`: SwiftUI View 層を触るときに使う
- `change-review`: 変更差分をリスクに応じてレビューする
- `thermo-nuclear-code-quality-review`: 構造劣化リスクがある変更では必須で使う
- `claude-review-request`: Goal の commit range など、別系統レビューとして Claude review が必要なときに使う
- `maintenance-audit`: 複数タスク後の構造・負債を棚卸しする（light / deep を scope で指定）
- `koecho-risk-check`: Koecho 固有の制約に照らして確認する
- `commit`: Conventional Commits 形式でコミットする

独立した調査・レビュー・実装は subagent で並列化してよい。subagent に依頼するときは、作業ディレクトリ `/Users/ryota/Sources/ryotapoi/Koecho` を明記する。

## Koecho Constraints

- SwiftUI + Model/Service パターンを基本とし、AppState が中核状態を保持し、ロジックは Services に分離する。
- `Koecho → KoechoPlatform → KoechoCore` の一方向依存を守る。KoechoCore に macOS 固有 API（AppKit, Carbon, CoreAudio 等）を import しない。
- NSTextView 依存のコード（DictationEngine 等）を App target の外に漏らさない。
- ディクテーション制御・テキストコミットのライフサイクル、volatile テキスト、`isSuppressingCallbacks`、NSTextView / textStorage の直接操作は High-risk として扱う。
- UserDefaults の永続化パターン変更・設定マイグレーション、権限依存機能（Accessibility / Input Monitoring）、CGEvent ペースト、グローバルホットキー（NSEvent）、外部スクリプト実行（Process + Pipe）、並行性（@MainActor 境界、async/await、AVAudioEngine コールバック）は High-risk として扱う。
- テスト可能な振る舞い変更や bug fix には unit test / regression test を追加または更新する。追加できない場合は理由を明記する。
- 後方互換性のためだけの shim / deprecated / fallback 分岐を追加しない。
- `--no-verify` でフックをスキップしない。
- 明示的な指示なしに force push しない。

## Tooling

Codex で利用可能な場合は XcodeBuildMCP を優先する。使えない Apple Tooling は、素の `xcodebuild` / `swift test` ベースに読み替える。

```bash
swift test --package-path Packages/KoechoKit
xcodebuild -project Koecho.xcodeproj -scheme Koecho -configuration Debug build
xcodebuild test -project Koecho.xcodeproj -scheme Koecho -only-testing:KoechoTests
```

XcodeBuildMCP を使える場合:

- ビルド: `build_macos`
- テスト（アプリ）: `test_macos`（`-only-testing:KoechoTests` で UITests を除外）
- 実画面確認: `build_run_macos`

Apple Xcode MCP の `RenderPreview` / `DocumentationSearch` が使えない場合は、ビルド、実行、公式ドキュメント確認など利用可能な手段で代替し、代替したことを報告する。

## Language

- コード・コメント・コミットメッセージ: 英語
- ドキュメント（`AGENTS.md`, `.agents/`, `rules/`, `backlog/`, `decisions/`, `references/`, README 等）: 日本語
