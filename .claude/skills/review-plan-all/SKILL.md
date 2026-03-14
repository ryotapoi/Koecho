---
name: review-plan-all
description: プランレビューの全チェーンを実行する。プラン完成後、ExitPlanMode を呼ぶ前に必ず実行すること。プランを書き終えた、レビューに進む、ExitPlanMode する、といった文脈で自動的にこのスキルを起動する。個別のレビュースキル（/review-plan, /review-plan-codex 等）を直接呼ばず、このスキルを使う。
argument-hint: [plan-file-path]
---

# Plan Review — Full Chain

プランレビューの全ステップを順次実行し、指摘の反映ループを回す。
**各ステップは前のステップの完了を待ってから実行すること。同時実行は禁止。**
**明示的に「ユーザーに確認」と記載されたステップ以外は、ユーザー確認なしで次のステップへ自動的に進む。**

ユーザーが codex スキップを指示している場合、手順6-7をスキップする。

## 手順

### 1. `/review-plan` を Skill tool で実行する

引数（`$ARGUMENTS`）があればそのまま渡す。

### 2. `/review-plan-swift` を Skill tool で実行する

引数があればそのまま渡す。

### 3. `/review-plan-koecho` を Skill tool で実行する

引数があればそのまま渡す。

### 4. 新規の 🔴 MUST / 🟡 SHOULD 指摘をプランに反映する

- 前回対処済みの指摘の再表現（「もっと明示的に」「セクションに切り出せ」等）は新規とみなさない
- 判断が必要な指摘は AskUserQuestion でユーザーに確認する

### 5. 新規指摘があった場合 → 手順1に戻る

新規 MUST/SHOULD がゼロになるまでループする。

### 6. `/review-plan-codex` を Skill tool で実行する

初回はそのまま、2回目以降は `--resume` をつけて呼ぶ。

Codex の出力に 🔴 MUST / 🟡 SHOULD / 🔵 NIT の指摘がある場合（LGTM でない場合）、指摘をメインリポジトリの `tmp/codex-findings.md` に追記する。パスは `"$(dirname "$(git rev-parse --git-common-dir)")/tmp/codex-findings.md"` で解決する（worktree でもメインリポに書く）。ファイルやディレクトリが存在しない場合は作成する。

```markdown
## YYYY-MM-DD plan: <変更の概要（1行）>

- 🔴/🟡/🔵 指摘内容の要約（1行）
- ...
```

### 7. 新規指摘があれば反映し、手順1に戻る

Codex レビューが2回目の場合、自動で反映せず指摘内容をユーザーに提示する。ユーザーがさらにループするか終了するか判断する。

### 8. 新規指摘なし → 完了

「プランレビュー完了。ExitPlanMode で承認を求めてください。」と報告する。
