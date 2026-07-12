import Foundation

public struct ReplacementRulePattern: Identifiable, Equatable, Sendable {
  public let id: UUID
  public var text: String

  public init(id: UUID = UUID(), text: String) {
    self.id = id
    self.text = text
  }
}

public struct ReplacementRule: Identifiable, Equatable, Sendable {
  public var id: UUID
  public var patterns: [ReplacementRulePattern]
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
    self.patterns = Self.makePatterns(from: patterns)
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
    get { patterns.first?.text ?? "" }
    set {
      if patterns.isEmpty {
        patterns = [ReplacementRulePattern(text: newValue)]
      } else {
        patterns[0].text = newValue
      }
    }
  }

  public var patternTexts: [String] {
    patterns.map(\.text)
  }

  public var displayName: String? {
    let nonEmpty: [String]
    if usesRegularExpression {
      nonEmpty = pattern.isEmpty ? [] : [pattern]
    } else {
      nonEmpty = patternTexts.filter { !$0.isEmpty }
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

  public static func == (lhs: ReplacementRule, rhs: ReplacementRule) -> Bool {
    lhs.id == rhs.id
      && lhs.patternTexts == rhs.patternTexts
      && lhs.replacement == rhs.replacement
      && lhs.usesRegularExpression == rhs.usesRegularExpression
      && lhs.matchesWholeWord == rhs.matchesWholeWord
  }

  private static func makePatterns(from texts: [String]) -> [ReplacementRulePattern] {
    let normalized = texts.isEmpty ? [""] : texts
    return normalized.map { ReplacementRulePattern(text: $0) }
  }
}

// MARK: - Codable

extension ReplacementRule: Codable {
  private enum CodingKeys: String, CodingKey {
    case id, patterns, replacement, usesRegularExpression, matchesWholeWord
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    replacement = try container.decode(String.self, forKey: .replacement)
    usesRegularExpression = try container.decode(Bool.self, forKey: .usesRegularExpression)
    matchesWholeWord = try container.decode(Bool.self, forKey: .matchesWholeWord)
    patterns = Self.makePatterns(from: try container.decode([String].self, forKey: .patterns))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(patternTexts, forKey: .patterns)
    try container.encode(replacement, forKey: .replacement)
    try container.encode(usesRegularExpression, forKey: .usesRegularExpression)
    try container.encode(matchesWholeWord, forKey: .matchesWholeWord)
  }
}

public struct ReplacementMatch: Equatable {
  public let range: NSRange  // Match range in the original text
  public let replacement: String  // Replacement string for this match

  public init(range: NSRange, replacement: String) {
    self.range = range
    self.replacement = replacement
  }
}
