# Plan Workflow

## ICAR

- **Intent**: 実装前に、要求・制約・設計判断・検証方針を必要十分な粒度で揃える。
- **Constraints**:
  - plan mode は使わない。計画は内部で立て、そのまま `implement.md` へ進む。ユーザー確認が必要なのは Stop Conditions に該当する場合だけ。
  - 原則 1 plan = 1 commit。独立した成果が混ざるなら plan を分ける。
  - 仕様・UX・データ保持・削除方針に複数の妥当な選択肢が実際にある場合はユーザー確認に回す。
  - 設計判断は採用案・却下案・理由を残す。
  - 検証方針（自動 / Preview 代替・アプリ起動確認 / ユーザー確認）を plan に明記する。
- **Acceptance**:
  - 実装対象、非対象、検証方針が明確。
  - 必要な `docs/specs/`, `backlog/backlog.md`, `docs/decisions/`, `llm-wiki/` の更新方針が明確。
  - レビュー指摘への対応が済んでいる、または対応しない理由が plan に書かれている。
  - レビュー指摘に対応しない場合は、plan に考慮したこと（不要と判断した理由・別タスクに切り出す理由・トレードオフ）を事実と理由で書く。
  - 未解決の不明点がない。ある場合はユーザー確認待ちとして止まっている。
- **Relevant**:
  - ユーザー依頼
  - `backlog/backlog.md`
  - 関連する `docs/rules/`, `docs/specs/`（あれば）, `docs/decisions/`, `llm-wiki/`
  - 関連コードと既存パターン

## Use When

- 複数ファイル変更
- 仕様・UX・データモデル・アーキテクチャに影響する変更
- High-risk 変更（`default.md` の Intake 分類）
- 実装方針が複数あり判断が必要
- リファクタを含む

Small（typo、docs、テスト追加だけ、1 ファイルの明確なバグ修正）は plan を省略してよい。

## Flow ICAR

### Design

- **Intent**: モジュール配置・共通化方針・型選択を、既存設計と長期保守性に沿って決める。
- **Constraints**:
  - 設計判断の前に `design-decision` skill を使う。
  - ルールに当てはめても決まらないときだけユーザー確認する。
  - モジュール配置（`Koecho → KoechoPlatform → KoechoCore` の依存方向）、共通化方針、型選択を判断する。配置・責務・依存方向そのものを問う場合は `module-boundary` を使う。
  - Koecho 固有制約に触れるなら `project-risk-check` で確認する。
- **Acceptance**: 採用案・却下案・理由・残リスクが plan に残っている。
- **Relevant**: `docs/rules/architecture.md`, `docs/rules/constraints.md`, `llm-wiki/`, 関連コード。

### Refactor Scope

- **Intent**: 理想状態は全体が綺麗であること。ただし 1 plan = 1 commit の粒度では、毎回全体を見直さず、今回の変更範囲で必要な構造改善を判断する。
- **Constraints**:
  - 今の構造を維持すること自体を目的にしない。
  - 調査範囲は、変更対象・直接の呼び出し元/呼び出し先・関連 specs / rules / llm-wiki に絞る。
  - その範囲で実装が歪む、重複が増える、責務境界が曖昧になるなら、先に局所リファクタするか今回の plan に含める。
  - 1 commit に収まらない広い構造改善は、今回に混ぜず `backlog/backlog.md` または `maintenance.md` の対象に切り出す。
  - `backlog/backlog.md` の直近バージョンに計画済みのリファクタ指摘は既知として扱う。
- **Acceptance**: そのまま実装 / 先に局所リファクタ / 今回に含める / 別 task に切る、の判断が plan にある。
- **Relevant**: 変更対象コード、直接の依存先/依存元、`backlog/backlog.md`, `maintenance.md`。

### Plan Review

- **Intent**: 実装前に plan の事実誤認・設計劣化・検証不足を見つける。
- **Constraints**:
  - 通常は実装後レビュー（`review.md`）を標準とし、plan review は self-check でよい。
  - 実装差分レビューでは Small 以外を原則 `change-review` に通すため、plan 時点でもレビュー深度と追加 skill の要否を明記する。
  - 領域固有リスクがあれば `project-risk-check`, `swiftui-pro` など該当観点を plan に当てる。
  - High-risk / 設計判断が重い / 曖昧 / 実装後では手戻りが大きい場合だけ、`claude-review-request` などの別系統レビューを検討する。
- **Acceptance**: 指摘が plan に反映済み、または対応しない理由が事実と理由で残っている。
- **Relevant**: plan、関連 specs / rules、レビュー観点 skill。

## Stop Conditions

- 1 commit に収まらない。
- High-risk なのに検証方針がない。
- 仕様・UX・設計方針をユーザー判断なしに決める必要がある（ただし `design-decision` で結論が出る範囲なら止まらず採否を決める）。
