import Foundation
import os

public struct ReplacementRule: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var patterns: [String]
    public var replacement: String
    public var usesRegularExpression: Bool
    public var matchesWholeWord: Bool

    public init(
        id: UUID = UUID(),
        patterns: [String],
        replacement: String = "",
        usesRegularExpression: Bool = false,
        matchesWholeWord: Bool = false
    ) {
        self.id = id
        self.patterns = patterns.isEmpty ? [""] : patterns
        self.replacement = replacement
        self.usesRegularExpression = usesRegularExpression
        self.matchesWholeWord = matchesWholeWord
    }

    /// Convenience initializer for single-pattern rules.
    public init(
        id: UUID = UUID(),
        pattern: String,
        replacement: String = "",
        usesRegularExpression: Bool = false,
        matchesWholeWord: Bool = false
    ) {
        self.init(
            id: id,
            patterns: [pattern],
            replacement: replacement,
            usesRegularExpression: usesRegularExpression,
            matchesWholeWord: matchesWholeWord
        )
    }

    /// First pattern, used by regex mode which always operates on a single pattern.
    public var pattern: String {
        get { patterns.first ?? "" }
        set {
            if patterns.isEmpty {
                patterns = [newValue]
            } else {
                patterns[0] = newValue
            }
        }
    }

    public var displayName: String? {
        let nonEmpty: [String]
        if usesRegularExpression {
            nonEmpty = pattern.isEmpty ? [] : [pattern]
        } else {
            nonEmpty = patterns.filter { !$0.isEmpty }
        }
        guard !nonEmpty.isEmpty else { return nil }
        let patternText = nonEmpty.joined(separator: ", ")
        if replacement.isEmpty { return patternText }
        return "\(patternText) → \(replacement)"
    }

    public func validate() -> String? {
        guard usesRegularExpression, !pattern.isEmpty else { return nil }
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

// MARK: - Codable

extension ReplacementRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, patterns, replacement, usesRegularExpression, matchesWholeWord
    }

    // Legacy key for migration from single-pattern format
    private enum LegacyCodingKeys: String, CodingKey {
        case pattern
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        replacement = try container.decode(String.self, forKey: .replacement)
        usesRegularExpression = try container.decode(Bool.self, forKey: .usesRegularExpression)
        matchesWholeWord = try container.decode(Bool.self, forKey: .matchesWholeWord)

        if container.contains(.patterns) {
            let decoded = try container.decode([String].self, forKey: .patterns)
            patterns = decoded.isEmpty ? [""] : decoded
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let single = try legacyContainer.decode(String.self, forKey: .pattern)
            patterns = [single]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(patterns, forKey: .patterns)
        try container.encode(replacement, forKey: .replacement)
        try container.encode(usesRegularExpression, forKey: .usesRegularExpression)
        try container.encode(matchesWholeWord, forKey: .matchesWholeWord)
    }
}

public struct ReplacementMatch: Equatable {
    public let range: NSRange       // Match range in the original text
    public let replacement: String  // Replacement string for this match

    public init(range: NSRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }
}

/// Build an NSRegularExpression for the given rule. Returns nil for invalid or empty patterns.
private func buildRegex(for rule: ReplacementRule) -> NSRegularExpression? {
    let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ReplacementRule")

    let regexPattern: String
    if rule.usesRegularExpression {
        guard !rule.pattern.isEmpty else { return nil }
        regexPattern = rule.pattern
    } else {
        // Filter non-empty, sort longest first to prevent shorter patterns from
        // consuming parts of longer ones (regex alternation is left-to-right).
        let nonEmpty = rule.patterns.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        guard !nonEmpty.isEmpty else { return nil }
        let alternatives = nonEmpty.map { p in
            let escaped = NSRegularExpression.escapedPattern(for: p)
            return rule.matchesWholeWord ? "\\b\(escaped)\\b" : escaped
        }
        regexPattern = alternatives.joined(separator: "|")
    }

    do {
        return try NSRegularExpression(pattern: regexPattern)
    } catch {
        logger.warning("Invalid regex pattern '\(regexPattern)': \(error.localizedDescription)")
        return nil
    }
}

/// Return the replacement template for the given rule.
private func buildTemplate(for rule: ReplacementRule) -> String {
    rule.usesRegularExpression
        ? rule.replacement
        : NSRegularExpression.escapedTemplate(for: rule.replacement)
}

public func applyReplacementRules(_ rules: [ReplacementRule], to text: String) -> String {
    var result = text
    for rule in rules {
        guard let regex = buildRegex(for: rule) else { continue }
        let template = buildTemplate(for: rule)
        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
    }
    return result
}

/// Find replacement matches without modifying text. Returns matches with ranges
/// in the original text coordinate system, suitable for overlay positioning.
///
/// Rules are applied sequentially on an intermediate text (same as `applyReplacementRules`),
/// but returned ranges are mapped back to original coordinates using per-position offset
/// tracking. Each prior rule's individual match deltas are tracked so that subsequent rules
/// get position-accurate mappings. When a later rule matches text that was generated by
/// an earlier replacement (not present in original), the mapped range may be approximate
/// and is filtered out by the caller's bounds check.
public func findReplacementMatches(_ rules: [ReplacementRule], in text: String) -> [ReplacementMatch] {
    guard !text.isEmpty else { return [] }

    var matches: [ReplacementMatch] = []
    // Sorted list of (intermediatePosition, cumulativeOffset).
    // For a position p in intermediate text, find the last entry with pos <= p
    // to get the offset. originalPosition = p - offset.
    var offsetEntries: [(pos: Int, offset: Int)] = [(0, 0)]
    var intermediateText = text

    for rule in rules {
        guard let regex = buildRegex(for: rule) else { continue }
        let template = buildTemplate(for: rule)

        let nsString = intermediateText as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let ruleMatches = regex.matches(in: intermediateText, range: fullRange)

        // Record matches and compute offset entries. Offset entries are collected
        // separately and merged after the loop to avoid affecting lookupOffset for
        // matches within the same rule (all matches in a rule use the pre-rule offsets).
        var newEntries: [(pos: Int, offset: Int)] = []
        var shiftSoFar = 0
        for result in ruleMatches {
            let matchRange = result.range
            let replacement = regex.replacementString(
                for: result,
                in: intermediateText,
                offset: 0,
                template: template
            )

            // Map intermediate position back to original coordinates
            let offset = lookupOffset(at: matchRange.location, in: offsetEntries)
            let originalLocation = matchRange.location - offset
            matches.append(ReplacementMatch(
                range: NSRange(location: originalLocation, length: matchRange.length),
                replacement: replacement
            ))

            // Track how this replacement shifts subsequent positions
            let delta = replacement.utf16.count - matchRange.length
            shiftSoFar += delta
            let oldEnd = matchRange.location + matchRange.length
            let newEnd = oldEnd + shiftSoFar
            let baseOffset = lookupOffset(at: oldEnd, in: offsetEntries)
            newEntries.append((newEnd, baseOffset + shiftSoFar))
        }
        offsetEntries.append(contentsOf: newEntries)
        offsetEntries.sort { $0.pos < $1.pos }

        intermediateText = regex.stringByReplacingMatches(
            in: intermediateText,
            range: fullRange,
            withTemplate: template
        )
    }

    return matches
}

private func lookupOffset(at position: Int, in entries: [(pos: Int, offset: Int)]) -> Int {
    var result = 0
    for entry in entries {
        if entry.pos > position { break }
        result = entry.offset
    }
    return result
}
