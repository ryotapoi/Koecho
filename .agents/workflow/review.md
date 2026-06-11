# Review Workflow

## ICAR

- **Intent**: 完了前に、差分が要求・仕様・既存設計を壊していないことを確認する。
- **Constraints**:
  - 粗探しではなく、実害・仕様逸脱・テスト不足・設計劣化を見る。
  - 小さい変更は self-check でよい。
  - テスト可能な振る舞い変更や bug fix に unit / regression test がない場合は、原則 blocker として扱う（理由がある例外のみ許容）。
  - 構造劣化リスク（巨大化、分岐増加、責務境界の濁り、薄い抽象化、型境界の曖昧さ）があれば `thermo-nuclear-code-quality-review` を必須で使う。
  - ディクテーション制御、NSTextView 操作、UserDefaults 永続化、権限依存機能、外部スクリプト実行、並行性、依存方向などの領域固有リスクは、該当 skill や別視点レビューを使う。
  - レビュー周回は最大 3 周。3 周で収束しなければそれ以上回さず打ち切る。打ち切った場合は残った指摘と周回数を記録し、タスク完了報告（Goal なら Goal 完了報告）で `レビュー上限超過` として通知する。
  - 指摘に対応しない場合は理由を残す。
- **Acceptance**:
  - 選んだレビュー深度と理由が説明できる。
  - テスト可能な振る舞い変更 / bug fix に unit / regression test がある、または追加しない理由が明確。
  - 指摘があれば対応済み、または対応しない理由が明確。
  - レビュー後に変更した場合、必要な再検証が済んでいる。
  - レビュー指摘 0 件、または残った指摘すべてが前回と根拠（why）が同じ再指摘、または最大周回数（3 周）で打ち切っている。
- **Relevant**:
  - 変更差分
  - plan または要求
  - 検証結果
  - 関連する `rules/`, `specs/`, `references/knowledge.md`

## Depth

- **Self-check**: Small 変更。main で `git diff` を読み、要求と検証結果を照合する。
- **Standard**: Small 以外の実装差分。`change-review` を通し、指摘を採否判断して反映する。
- **Targeted supplement**: 領域固有リスクがある変更。Standard に加えて該当観点の skill を使う。
- **External supplement**: 大きい、曖昧、High-risk、または設計判断が重い変更。Standard に加えて別系統レビューを入れる（Goal では `goal.md` の Claude review。単発で Claude review が必要ならユーザーに確認してから `claude-review-request` を使う）。
- **Maintenance**: 今回の差分ではなく、複数タスク後の全体構造・負債を見る。`maintenance.md` を使う。

Goal 全体の commit range に対する Claude review は、各 commit のここでの review とは別に Goal 完了条件として `goal.md` の Claude Review で実施する。

## Koecho Review Triggers

- SwiftUI View 層 → `swiftui-pro`
- ディクテーション制御・テキストライフサイクル（volatile テキスト、`isSuppressingCallbacks`）
- NSTextView / textStorage 操作
- UserDefaults 永続化パターン、設定マイグレーション
- 権限依存機能（Accessibility / Input Monitoring）
- ホットキー・ペースト・選択テキスト取得
- 外部スクリプト実行（Process + Pipe）
- 永続化 / マイグレーション / 削除 / 外部連携 / 並行性 / 公開 API
- `Koecho → KoechoPlatform → KoechoCore` の依存方向
- README / rules / references と実装の同期

上記に該当する場合は `koecho-risk-check` を使う。構造劣化リスクがある場合は `thermo-nuclear-code-quality-review` も必須で使う。

## How To Run

- Self-check: main で `git diff` を読み、acceptance と照合する。
- Standard: `change-review` を実行し、戻ってきた指摘を採否判断して反映する。
- Targeted / External supplement: 該当 skill（`koecho-risk-check`, `swiftui-pro`, `thermo-nuclear-code-quality-review`, `claude-review-request`）を使う。
- 複数該当するものは並列起動してよい。
- 戻りを全部受け取ってから main で統合し、採用分をまとめて反映する。実行中に 1 件ずつ反映しない。

## Stop Conditions

- 指摘対応が仕様・UX・設計方針を変える。
- 必要な別視点レビューが実行できない。
