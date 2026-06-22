---
name: cross-agent-review
description: Use when a workflow requires Cross-Agent Review from Codex to Claude Code for a commit range, current diff, or follow-up review. Thin wrapper around claude-review-request; keeps workflow files independent from low-level Claude tmux orchestration.
---

# Cross-Agent Review

## ICAR

- **Intent**: Codex 側 workflow から、別系統の Claude Code に commit range / diff / follow-up をレビューさせる共通入口にする。
- **Constraints**:
  - 実レビューの実行は `claude-review-request` に委譲する。
  - この skill は tmux 起動、prompt/result file、model/effort などの低レベル手順を重複記述しない。
  - 修正は Codex 側が行う。Claude Code は外部レビュアーとして指摘を返す。
  - 入出力 schema を細かく固定しない。呼び出し元がレビューできる対象と文脈を渡し、戻りから `PASS` / `CHANGES_REQUIRED` / `UNAVAILABLE` 相当を判断できればよい。
- **Acceptance**:
  - Claude Code review が実施され、指摘または LGTM が返っている。
  - 実施不能な場合は、未レビュー範囲を完了扱いにせず、理由が分かる。
- **Relevant**:
  - `claude-review-request`
  - review 対象の commit range / diff / follow-up context
  - Goal / Change の要求、検証結果、関連 docs

## How To Run

1. review 対象を決める:
   - Goal Review なら未レビュー range（例: `<review_cursor>..HEAD`）。
   - follow-up review なら元レビュー対象、対応 commit / range、対応内容の要約。
   - 明示 range がなければ、現在の未コミット差分。
2. `claude-review-request` を使い、review 対象と必要な文脈を自然言語で渡す。固定 schema にはしないが、分かる範囲で次を含める:
   - review 対象の range / diff / follow-up context
   - Goal または Change の目的と変更意図
   - 関連する検証結果、重要な docs / specs / decisions
3. Claude Code の戻りを読み、呼び出し元 workflow が採否と次の動きを決める。

## Output Handling

- LGTM または実害ある指摘がなければ `PASS` 相当として扱ってよい。
- MUST / SHOULD 相当の指摘があれば `CHANGES_REQUIRED` 相当として扱い、修正 Change を作る。指摘には採否判断に必要な根拠があること。
- Claude Code review を完全に実施できない場合は `UNAVAILABLE` 相当として扱い、未レビュー範囲を完了扱いにしない。実施不能の理由が分かること。
