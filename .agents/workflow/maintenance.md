# Maintenance Workflow

## ICAR

- **Intent**: 単一タスクの範囲を超えて、構造・負債・重複・テスト戦略を棚卸しし、必要な改善タスクを作る。
- **Constraints**:
  - タスク内ではなく、節目で呼ぶ。タスク完了の度に呼ぶものではない。
  - 今回の差分ではなく、今後の変更コストを下げる観点で見る。
  - 改善タスクは 1 commit に収まる粒度にする。
  - 仕様や設計方針の変更が必要なら `docs/decisions/` または `docs/rules/` 更新を検討する。
- **Acceptance**:
  - 構造上の問題、リファクタ候補、テスト戦略の不足が整理されている。
  - 必要な改善が `backlog/backlog.md` に追跡可能な形で入っている。
  - すぐ着手する改善と先送りする改善が分かれている。
- **Relevant**:
  - 最近の git history
  - `backlog/backlog.md`
  - 変更が多かったモジュール（`Koecho/` App target、`Packages/KoechoKit/` 配下）
  - `docs/rules/architecture.md`
  - `llm-wiki/`

## Flow ICAR

### Scope Selection

- **Intent**: maintenance を呼ぶべき節目かどうかを判定する。
- **Constraints**:
  - 複数コミットやマイルストーン（v1.4, v1.5 など）の区切りで使う。
  - 同じ種類の修正が続いている、または review で同種の指摘が繰り返されたときに使う。
  - 実装中やレビューでリファクタ候補が複数出た、または久々に広い領域を触ったときに使う。
- **Acceptance**:
  - maintenance の深さと対象範囲を説明できる。

### Audit

- **Intent**: 構造・負債・重複・テスト戦略を棚卸しする。
- **Acceptance**:
  - 問題、改善候補、先送り理由が混ざらず整理されている。

### Follow-up Handling

- **Intent**: maintenance で見つかった改善を、追跡可能な作業へ落とす。
- **Constraints**:
  - すぐ直す改善は、独立した 1 commit workflow として扱う。
  - 先送りする改善は `backlog/backlog.md` に残す。
- **Acceptance**:
  - すぐ着手する改善と先送りする改善が分かれている。
  - backlog に積む場合は後で拾える粒度になっている。

## Tools

- 棚卸し・健康診断: `maintenance-audit` skill（軽い整合性・負債・backlog 鮮度の light pass から、テスト・カバレッジ・行数・依存方向・凝集度・分割の deep pass まで、scope で深さを指定）
- llm-wiki 点検: `wiki-lint` skill（孤立・リンク切れ・sources 切れと「速い / docs レベルでない / 嘘がない / 拾える」の不変条件を確認）
- module / 配置 / 依存方向の境界判断: `module-boundary` skill

## Stop Conditions

- 改善が大きすぎて複数タスクに分割すべき。
- プロダクト方針やアーキテクチャ方針の判断が必要。
