import Foundation
import os

struct ReplacementRule: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var pattern: String
    var replacement: String
    var usesRegularExpression: Bool
    var matchesWholeWord: Bool

    init(
        id: UUID = UUID(),
        pattern: String,
        replacement: String = "",
        usesRegularExpression: Bool = false,
        matchesWholeWord: Bool = false
    ) {
        self.id = id
        self.pattern = pattern
        self.replacement = replacement
        self.usesRegularExpression = usesRegularExpression
        self.matchesWholeWord = matchesWholeWord
    }

    var displayName: String {
        if pattern.isEmpty { return "New Rule" }
        if replacement.isEmpty { return pattern }
        return "\(pattern) → \(replacement)"
    }
}

func applyReplacementRules(_ rules: [ReplacementRule], to text: String) -> String {
    let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "ReplacementRule")

    var result = text
    for rule in rules {
        guard !rule.pattern.isEmpty else { continue }

        let regexPattern: String
        if rule.usesRegularExpression {
            regexPattern = rule.pattern
        } else {
            let escaped = NSRegularExpression.escapedPattern(for: rule.pattern)
            regexPattern = rule.matchesWholeWord ? "\\b\(escaped)\\b" : escaped
        }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: regexPattern)
        } catch {
            logger.warning("Invalid regex pattern '\(rule.pattern)': \(error.localizedDescription)")
            continue
        }

        let template = rule.usesRegularExpression
            ? rule.replacement
            : NSRegularExpression.escapedTemplate(for: rule.replacement)
        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
    }
    return result
}
