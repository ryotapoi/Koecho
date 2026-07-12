# ADR 0020: Multiple Patterns per Replacement Rule

## Status

Accepted

## Context

In plain text replacement mode, users often need multiple source patterns that map to the same replacement (e.g., "GitHブ", "ギットHub" → "GitHub"). Previously, each pattern required a separate rule, making management cumbersome. We needed to support multiple patterns per rule while keeping regex mode single-pattern.

## Considered Options

- **A: `patterns: [String]` with `|` join in regex**: Store multiple patterns, join them with `|` into a single `NSRegularExpression`. Longest-first sort prevents shorter patterns from consuming parts of longer ones.
- **B: Loop-based application**: Apply each pattern sequentially within a single rule. Risk: earlier replacements could be matched by later patterns in the same rule.
- **C: Identifiable pattern entries**: Wrap each pattern in an `Identifiable` struct for stable SwiftUI ForEach identity. More complex Codable and data model.

## Decision

We will use option A: `patterns: [String]` joined with `|` after longest-first sorting.

- `pattern: String` stored property replaced with `patterns: [String]`
- Convenience `pattern` computed property (get/set on `patterns[0]`) preserved for regex mode and backward compatibility
- Custom `Codable` with legacy `pattern` key fallback for migration
- `displayName` returns `String?` (nil when empty) so the view layer handles localization

## Consequences

- Positive: Single-pass regex matching is efficient and avoids inter-pattern interference within a rule
- Positive: Longest-first sort prevents prefix-match issues (e.g., "Git" consuming "GitHub")
- Positive: Legacy data migrates automatically on first load
- Negative: `pattern` computed property creates a dual interface (`pattern` / `patterns`) that could confuse future contributors
- Superseded negative: ForEach with index-based identity may cause animation glitches on pattern add/remove (acceptable for v1 given small pattern counts)
- Neutral: Encode always uses `patterns` key; old app versions cannot read new data (per mission.md non-goal)

## 追記 2026-07-05: 編集 UI の行 identity

`ReplacementRuleEditView` の pattern 行は、途中削除時に index identity がずれると TextField の focus / row state / insertion-removal animation が別行へ移るリスクがある。

別案:
- index identity を維持する: 保存形式もモデルも小さいが、UI の行 identity が位置に紐づく問題は残る。
- pattern 文字列を identity にする: content-derived ID になり、編集中の文字列変更で identity が変わる。重複 pattern も扱えない。
- pattern 行を ID 付き値型にする: UI identity を型で表せるが、Codable と文字列処理の boundary を明示する必要がある。

採用:
pattern 行を `ReplacementRulePattern` として ID 付き値型にする。保存データの `patterns` は引き続き `[String]` として encode/decode し、decode 時に新しい行 ID を生成する。行 ID は UI identity 用で永続 ID ではないため、`ReplacementRule` の等価性には含めない。

影響:
SwiftUI の `ForEach` は pattern 行の安定 ID を使える。既存の UserDefaults JSON 形式は変わらない。置換ロジックや重複検出は `patternTexts` を通じて保存対象の文字列列を読む。

## 追記 2026-07-13: 旧単数形式の移行終了

2026-06-11 のユーザー判断に従い、v1.4.x / v1.5.x で確保した移行期間の終了後、v1.6.6 で `pattern` 単数キーの decode fallback を撤去した。以後の保存形式は `patterns` のみとし、旧形式は暗黙に移行しない。これは mission.md の旧フォーマット fallback を置かない方針に整合する。
