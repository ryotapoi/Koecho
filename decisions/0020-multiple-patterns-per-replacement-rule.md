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
- Negative: ForEach with index-based identity may cause animation glitches on pattern add/remove (acceptable for v1 given small pattern counts)
- Neutral: Encode always uses `patterns` key; old app versions cannot read new data (per mission.md non-goal)
