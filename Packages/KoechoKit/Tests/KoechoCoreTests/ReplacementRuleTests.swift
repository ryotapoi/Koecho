import Foundation
import Testing

@testable import KoechoCore

@MainActor
struct ReplacementRuleTests {
  // MARK: - Plain text search

  @Test func plainTextReplacement() {
    let rules = [
      ReplacementRule(pattern: "えーと", replacement: "")
    ]
    let result = applyReplacementRules(rules, to: "えーと今日はえーと天気がいいです")
    #expect(result == "今日は天気がいいです")
  }

  @Test func plainTextMatchWholeWordOn() {
    let rules = [
      ReplacementRule(pattern: "the", replacement: "a", matchesWholeWord: true)
    ]
    let result = applyReplacementRules(rules, to: "the other the")
    #expect(result == "a other a")
  }

  @Test func plainTextMatchWholeWordOff() {
    let rules = [
      ReplacementRule(pattern: "the", replacement: "X")
    ]
    let result = applyReplacementRules(rules, to: "the other the")
    #expect(result == "X oXr X")
  }

  // MARK: - Regex mode

  @Test func regexBasicReplacement() {
    let rules = [
      ReplacementRule(pattern: "\\s+", replacement: " ", usesRegularExpression: true)
    ]
    let result = applyReplacementRules(rules, to: "hello   world\t\tfoo")
    #expect(result == "hello world foo")
  }

  @Test func regexCaptureGroups() {
    let rules = [
      ReplacementRule(pattern: "(\\w+) (\\w+)", replacement: "$2 $1", usesRegularExpression: true)
    ]
    let result = applyReplacementRules(rules, to: "hello world")
    #expect(result == "world hello")
  }

  @Test func regexInvalidPatternSkipped() {
    let rules = [
      ReplacementRule(pattern: "[invalid", replacement: "x", usesRegularExpression: true)
    ]
    let result = applyReplacementRules(rules, to: "hello")
    #expect(result == "hello")
  }

  // MARK: - Plain text with regex metacharacters

  @Test func plainTextEscapesMetacharacters() {
    let rules = [
      ReplacementRule(pattern: "$100", replacement: "100 dollars")
    ]
    let result = applyReplacementRules(rules, to: "Price is $100 today")
    #expect(result == "Price is 100 dollars today")
  }

  @Test func plainTextReplacementWithDollarSign() {
    let rules = [
      ReplacementRule(pattern: "price", replacement: "$100")
    ]
    let result = applyReplacementRules(rules, to: "The price is here")
    #expect(result == "The $100 is here")
  }

  // MARK: - Multiple rules

  @Test func multipleRulesAppliedInOrder() {
    let rules = [
      ReplacementRule(pattern: "A", replacement: "B"),
      ReplacementRule(pattern: "B", replacement: "C"),
    ]
    let result = applyReplacementRules(rules, to: "A")
    #expect(result == "C")
  }

  // MARK: - Regex mode ignores matchesWholeWord

  @Test func regexModeIgnoresMatchesWholeWord() {
    let rules = [
      ReplacementRule(
        pattern: "the",
        replacement: "X",
        usesRegularExpression: true,
        matchesWholeWord: true
      )
    ]
    // In regex mode, matchesWholeWord is ignored so "the" inside "other" should also match
    let result = applyReplacementRules(rules, to: "the other the")
    #expect(result == "X oXr X")
  }

  // MARK: - findReplacementMatches

  @Test func findMatchesSingleRuleMultipleMatches() {
    let rules = [ReplacementRule(pattern: "えーと", replacement: "")]
    let matches = findReplacementMatches(rules, in: "えーと天気えーと")
    #expect(matches.count == 2)
    #expect(matches[0] == ReplacementMatch(range: NSRange(location: 0, length: 3), replacement: ""))
    #expect(matches[1] == ReplacementMatch(range: NSRange(location: 5, length: 3), replacement: ""))
  }

  @Test func findMatchesMultipleIndependentRules() {
    // Two independent rules that don't overlap
    let rules = [
      ReplacementRule(pattern: "えーと", replacement: ""),
      ReplacementRule(pattern: "あのー", replacement: ""),
    ]
    let matches = findReplacementMatches(rules, in: "えーとあのー天気")
    #expect(matches.count == 2)
    // Rule 1 matches "えーと" at (0,3) in original
    #expect(matches[0] == ReplacementMatch(range: NSRange(location: 0, length: 3), replacement: ""))
    // After rule 1, intermediate = "あのー天気", cumulativeOffset = -3
    // Rule 2 matches "あのー" at (0,3) in intermediate, original = 0 - (-3) = 3
    #expect(matches[1] == ReplacementMatch(range: NSRange(location: 3, length: 3), replacement: ""))
  }

  @Test func previewMatchesChainedApplicationAndMapsToOriginalOffsets() {
    let rules = [
      ReplacementRule(pattern: "ab", replacement: "WXYZ"),
      ReplacementRule(pattern: "WXYZ", replacement: "Q"),
    ]
    let text = "ab-ab"

    #expect(applyReplacementRules(rules, to: text) == "Q-Q")
    #expect(
      findReplacementMatches(rules, in: text) == [
        ReplacementMatch(range: NSRange(location: 0, length: 2), replacement: "Q"),
        ReplacementMatch(range: NSRange(location: 3, length: 2), replacement: "Q"),
      ]
    )
  }

  @Test func insertionPointFollowsSequentialReplacements() {
    let cases: [(String, Int, [(String, String)], String, Int)] = [
      ("a b", 1, [("a", "long"), ("long", "x")], "x b", 1),
      ("aZ", 1, [("a", "bbbb"), ("bbbb", "c")], "cZ", 1),
      ("a z t", 5, [("z", "zzzz"), ("a", "aaa"), ("t", "TT")], "aaa zzzz TT", 11),
      ("abcFILLERz", 4, [("FILLER", "")], "abcz", 3),
    ]
    for (text, point, pairs, expectedText, expectedPoint) in cases {
      let rules = pairs.map { ReplacementRule(pattern: $0.0, replacement: $0.1) }
      let result = applyReplacementRules(rules, to: text, insertionPoint: point)
      #expect(result.text == expectedText)
      #expect(result.insertionPoint == expectedPoint)
    }
  }

  @Test func insertionPointMapsMatchBoundariesAndUTF16() {
    let rules = [ReplacementRule(pattern: "😀ab", replacement: "猫")]
    for (point, expected) in [(1, 1), (3, 2), (5, 2), (6, 3)] {
      let result = applyReplacementRules(rules, to: "x😀abZ", insertionPoint: point)
      #expect(result.text == "x猫Z")
      #expect(result.insertionPoint == expected)
    }
    let deletion = [ReplacementRule(pattern: "😀ab", replacement: "")]
    for (point, expected) in [(1, 1), (3, 1), (5, 1), (6, 2)] {
      #expect(applyReplacementRules(deletion, to: "x😀abZ", insertionPoint: point).insertionPoint == expected)
    }
  }

  @Test func previewTracksLaterFrontEditsAndPartialGeneratedMatches() {
    let rules = [
      ReplacementRule(pattern: "z", replacement: "zzzz"),
      ReplacementRule(pattern: "a", replacement: "aaa"),
      ReplacementRule(pattern: "t", replacement: "TT"),
    ]
    #expect(findReplacementMatches(rules, in: "a z t") == [
      ReplacementMatch(range: NSRange(location: 0, length: 1), replacement: "aaa"),
      ReplacementMatch(range: NSRange(location: 2, length: 1), replacement: "zzzz"),
      ReplacementMatch(range: NSRange(location: 4, length: 1), replacement: "TT"),
    ])
    let partial = [
      ReplacementRule(pattern: "😀", replacement: "abcd"),
      ReplacementRule(pattern: "bc", replacement: "X"),
      ReplacementRule(pattern: "dZ", replacement: "!"),
    ]
    #expect(findReplacementMatches(partial, in: "😀Z") == [
      ReplacementMatch(range: NSRange(location: 0, length: 3), replacement: "aX!")
    ])
  }

  @Test func previewRetainsDeletionAndZeroWidthRegexInsertions() {
    let rules = [ReplacementRule(pattern: "FILLER", replacement: "")]
    #expect(findReplacementMatches(rules, in: "abcFILLERz") == [
      ReplacementMatch(range: NSRange(location: 3, length: 6), replacement: "")
    ])
    let insertion = [
      ReplacementRule(pattern: "^|$", replacement: "!", usesRegularExpression: true),
      ReplacementRule(pattern: "!", replacement: "??"),
    ]
    #expect(findReplacementMatches(insertion, in: "a") == [
      ReplacementMatch(range: NSRange(location: 0, length: 0), replacement: "??"),
      ReplacementMatch(range: NSRange(location: 1, length: 0), replacement: "??"),
    ])
  }

  @Test func findMatchesRegexCaptureGroups() {
    let rules = [
      ReplacementRule(
        pattern: "(\\w+) (\\w+)",
        replacement: "$2 $1",
        usesRegularExpression: true
      )
    ]
    let matches = findReplacementMatches(rules, in: "hello world")
    #expect(matches.count == 1)
    #expect(
      matches[0]
        == ReplacementMatch(range: NSRange(location: 0, length: 11), replacement: "world hello"))
  }

  @Test func findMatchesWholeWord() {
    let rules = [
      ReplacementRule(pattern: "the", replacement: "a", matchesWholeWord: true)
    ]
    let matches = findReplacementMatches(rules, in: "the other the")
    #expect(matches.count == 2)
    #expect(
      matches[0] == ReplacementMatch(range: NSRange(location: 0, length: 3), replacement: "a"))
    #expect(
      matches[1] == ReplacementMatch(range: NSRange(location: 10, length: 3), replacement: "a"))
  }

  @Test func findMatchesDollarSignInReplacement() {
    let rules = [ReplacementRule(pattern: "price", replacement: "$100")]
    let matches = findReplacementMatches(rules, in: "The price is here")
    #expect(matches.count == 1)
    #expect(
      matches[0] == ReplacementMatch(range: NSRange(location: 4, length: 5), replacement: "$100"))
  }

  // MARK: - validate

  @Test func validateRegexEmptyPatternReturnsNil() {
    let rule = ReplacementRule(pattern: "", usesRegularExpression: true)
    #expect(rule.validate() == nil)
  }

  @Test func validateRegexValidPatternReturnsNil() {
    let rule = ReplacementRule(pattern: "\\d+", usesRegularExpression: true)
    #expect(rule.validate() == nil)
  }

  @Test func validateRegexInvalidPatternReturnsError() {
    let rule = ReplacementRule(pattern: "[invalid", usesRegularExpression: true)
    #expect(rule.validate() != nil)
  }

  @Test func validatePlainTextWithRegexMetacharactersReturnsNil() {
    let rule = ReplacementRule(pattern: "[invalid")
    #expect(rule.validate() == nil)
  }

  // MARK: - Codable

  @Test func decodeLegacySinglePatternFormatFails() {
    let json = """
      {
          "id": "00000000-0000-0000-0000-000000000001",
          "pattern": "えーと",
          "replacement": "",
          "usesRegularExpression": false,
          "matchesWholeWord": false
      }
      """.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ReplacementRule.self, from: json)
    }
  }

  @Test func decodeNewPatternsFormat() throws {
    let json = """
      {
          "id": "00000000-0000-0000-0000-000000000002",
          "patterns": ["GitHブ", "ギットHub"],
          "replacement": "GitHub",
          "usesRegularExpression": false,
          "matchesWholeWord": false
      }
      """.data(using: .utf8)!
    let rule = try JSONDecoder().decode(ReplacementRule.self, from: json)
    #expect(rule.patternTexts == ["GitHブ", "ギットHub"])
    #expect(rule.pattern == "GitHブ")
    #expect(rule.replacement == "GitHub")
  }

  @Test func encodeUsesPatternsKey() throws {
    let rule = ReplacementRule(pattern: "test", replacement: "replaced")
    let data = try JSONEncoder().encode(rule)
    let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(dict["patterns"] as? [String] == ["test"])
    #expect(dict["pattern"] == nil)
    #expect((dict["patterns"] as? [[String: Any]]) == nil)
  }

  @Test func codableRoundTrip() throws {
    let rule = ReplacementRule(
      patterns: ["a", "b"],
      replacement: "c",
      usesRegularExpression: false,
      matchesWholeWord: true
    )
    let data = try JSONEncoder().encode(rule)
    let decoded = try JSONDecoder().decode(ReplacementRule.self, from: data)
    #expect(decoded.patternTexts == ["a", "b"])
    #expect(decoded.replacement == "c")
    #expect(decoded.matchesWholeWord == true)
    #expect(decoded.id == rule.id)
    #expect(decoded == rule)
    #expect(decoded.patterns.map(\.id) != rule.patterns.map(\.id))
  }

  @Test func decodeEmptyPatternsArrayFallsBack() throws {
    let json = """
      {
          "id": "00000000-0000-0000-0000-000000000004",
          "patterns": [],
          "replacement": "",
          "usesRegularExpression": false,
          "matchesWholeWord": false
      }
      """.data(using: .utf8)!
    let rule = try JSONDecoder().decode(ReplacementRule.self, from: json)
    #expect(rule.patternTexts == [""])
  }

  // MARK: - pattern computed property

  @Test func patternComputedPropertySetUpdatesFirst() {
    var rule = ReplacementRule(patterns: ["a", "b"], replacement: "c")
    let firstPatternID = rule.patterns[0].id
    rule.pattern = "x"
    #expect(rule.patternTexts == ["x", "b"])
    #expect(rule.patterns[0].id == firstPatternID)
  }

  // MARK: - empty array prevention

  @Test func initWithEmptyPatternsArrayFallsBack() {
    let rule = ReplacementRule(patterns: [], replacement: "x")
    #expect(rule.patternTexts == [""])
  }

  // MARK: - stable pattern identity

  @Test func replacementPatternIDsAreUniquePerElement() {
    let rule = ReplacementRule(patterns: ["same", "same"], replacement: "x")
    #expect(rule.patterns[0].id != rule.patterns[1].id)
  }

  @Test func replacementRuleEqualityIgnoresNonPersistentPatternIDs() {
    let id = UUID()
    let lhs = ReplacementRule(id: id, patterns: ["a", "b"], replacement: "c")
    let rhs = ReplacementRule(id: id, patterns: ["a", "b"], replacement: "c")
    #expect(lhs == rhs)
    #expect(lhs.patterns.map(\.id) != rhs.patterns.map(\.id))
  }

  // MARK: - displayName with all-empty patterns

  @Test func displayNameAllEmptyPatterns() {
    let rule = ReplacementRule(patterns: ["", ""], replacement: "x")
    #expect(rule.displayName == nil)
  }

  // MARK: - Multiple patterns (plain text mode)

  @Test func multiplePatternsBasicReplacement() {
    let rules = [
      ReplacementRule(patterns: ["GitHブ", "ギットHub"], replacement: "GitHub")
    ]
    let result = applyReplacementRules(rules, to: "GitHブとギットHubを使う")
    #expect(result == "GitHubとGitHubを使う")
  }

  @Test func multiplePatternsLongestMatchFirst() {
    // "GitHub" should match before "Git" due to longest-first sorting
    let rules = [
      ReplacementRule(patterns: ["Git", "GitHub"], replacement: "X")
    ]
    let result = applyReplacementRules(rules, to: "GitHub is great")
    #expect(result == "X is great")
  }

  @Test func multiplePatternsWithEmptyElement() {
    // Empty patterns should be filtered out
    let rules = [
      ReplacementRule(patterns: ["", "foo", ""], replacement: "bar")
    ]
    let result = applyReplacementRules(rules, to: "foo and foo")
    #expect(result == "bar and bar")
  }

  @Test func multiplePatternsAllEmpty() {
    let rules = [
      ReplacementRule(patterns: ["", ""], replacement: "x")
    ]
    let result = applyReplacementRules(rules, to: "hello")
    #expect(result == "hello")
  }

  @Test func multiplePatternsWithWholeWord() {
    let rules = [
      ReplacementRule(
        patterns: ["the", "a"],
        replacement: "X",
        matchesWholeWord: true
      )
    ]
    let result = applyReplacementRules(rules, to: "the cat ate a thing")
    #expect(result == "X cat ate X thing")
  }

  @Test func multiplePatternsRegexStillSingle() {
    // Regex mode uses only patterns.first
    let rules = [
      ReplacementRule(
        patterns: ["\\d+", "ignored"],
        replacement: "N",
        usesRegularExpression: true
      )
    ]
    let result = applyReplacementRules(rules, to: "abc 123 ignored")
    #expect(result == "abc N ignored")
  }

  // MARK: - findReplacementMatches with multiple patterns

  @Test func findMatchesMultiplePatterns() {
    let rules = [
      ReplacementRule(patterns: ["GitHブ", "ギットHub"], replacement: "GitHub")
    ]
    let matches = findReplacementMatches(rules, in: "GitHブとギットHub")
    #expect(matches.count == 2)
    #expect(matches[0].replacement == "GitHub")
    #expect(matches[1].replacement == "GitHub")
  }

  // MARK: - displayName with multiple non-empty patterns

  @Test func displayNameMultiplePatterns() {
    let rule = ReplacementRule(
      patterns: ["GitHブ", "ギットHub"],
      replacement: "GitHub"
    )
    #expect(rule.displayName == "GitHブ, ギットHub → GitHub")
  }

  @Test func displayNameMultiplePatternsNoReplacement() {
    let rule = ReplacementRule(patterns: ["foo", "bar"], replacement: "")
    #expect(rule.displayName == "foo, bar")
  }

  @Test func displayNameMultiplePatternsWithSomeEmpty() {
    let rule = ReplacementRule(patterns: ["", "foo", ""], replacement: "bar")
    #expect(rule.displayName == "foo → bar")
  }
  @Test func singleCandidatesUseCurrentTextWithoutChaining() {
    let rules = [ReplacementRule(pattern: "a", replacement: "bbbb"),
      ReplacementRule(pattern: "bbbb", replacement: "c")]
    let candidates = findReplacementCandidates(rules, in: "a a bbbb")
    #expect(candidates == [
      ReplacementMatch(range: NSRange(location: 0, length: 1), replacement: "bbbb"),
      ReplacementMatch(range: NSRange(location: 2, length: 1), replacement: "bbbb"),
      ReplacementMatch(range: NSRange(location: 4, length: 4), replacement: "c")])
    let result = applyReplacementMatch(candidates[1], to: "a a bbbb", insertionPoint: 3)
    #expect(result.text == "a bbbb bbbb")
    #expect(result.insertionPoint == 6)
  }

  @Test func singleCandidatesRespectRuleOrderAndMatchingModes() {
    let candidates = findReplacementCandidates([
      ReplacementRule(patterns: ["cat", "cater"], replacement: "pet", matchesWholeWord: true),
      ReplacementRule(pattern: "(cat)(er)", replacement: "$2-$1", usesRegularExpression: true)
    ], in: "cater cat scatter")
    #expect(candidates == [
      ReplacementMatch(range: NSRange(location: 0, length: 5), replacement: "pet"),
      ReplacementMatch(range: NSRange(location: 6, length: 3), replacement: "pet")])
    #expect(findReplacementCandidates([
      ReplacementRule(pattern: "(cat)(er)", replacement: "$2-$1", usesRegularExpression: true)
    ], in: "cater").first?.replacement == "er-cat")
  }

  @Test func singleDeletionMapsUTF16PointsInsideAndAfterMatch() {
    let text = "😀removeZ"
    let match = findReplacementCandidates([ReplacementRule(pattern: "remove", replacement: "")], in: text)[0]
    #expect(match.range == NSRange(location: 2, length: 6))
    #expect(applyReplacementMatch(match, to: text, insertionPoint: 2).insertionPoint == 2)
    #expect(applyReplacementMatch(match, to: text, insertionPoint: 4).insertionPoint == 2)
    #expect(applyReplacementMatch(match, to: text, insertionPoint: 8).insertionPoint == 2)
    #expect(applyReplacementMatch(match, to: text, insertionPoint: 9).text == "😀Z")
    #expect(applyReplacementMatch(match, to: text, insertionPoint: 9).insertionPoint == 3)
  }

  @Test func zeroWidthRegexOnlyAppliesToWholeDocument() {
    let rules = [ReplacementRule(pattern: "^", replacement: "start", usesRegularExpression: true)]
    #expect(findReplacementCandidates(rules, in: "text").isEmpty)
    #expect(applyReplacementRules(rules, to: "text") == "starttext")
  }

  @Test(arguments: [2, 3, 4, 5, 6, 7]) func localTargetsIncludeBothCaretEdges(position: Int) {
    let match = ReplacementMatch(range: NSRange(location: 3, length: 3), replacement: "x")
    #expect(replacementTargets([match], selection: NSRange(location: position, length: 0)) ==
      (position >= 3 && position <= 6 ? [match] : []))
  }

  @Test func localTargetsOwnLeftBoundaryAndRequireCompleteContainment() {
    let a = ReplacementMatch(range: NSRange(location: 0, length: 2), replacement: "long")
    let b = ReplacementMatch(range: NSRange(location: 2, length: 2), replacement: "")
    #expect(replacementTargets([b, a], selection: NSRange(location: 2, length: 0)) == [a])
    #expect(replacementTargets([a, b], selection: NSRange(location: 0, length: 4)) == [a, b])
    #expect(replacementTargets([a, b], selection: NSRange(location: 1, length: 3)) == [b])
    #expect(replacementTargets([a, b], selection: NSRange(location: 1, length: 2)).isEmpty)
  }

  @Test func snapshotEditsMapUnicodePointsWithoutSearchingGeneratedText() {
    let text = "😀ab cde fZ"
    let matches = [
      ReplacementMatch(range: NSRange(location: 2, length: 2), replacement: "LONG"),
      ReplacementMatch(range: NSRange(location: 5, length: 3), replacement: "x"),
      ReplacementMatch(range: NSRange(location: 9, length: 1), replacement: "")]
    let expected = [0, 1, 2, 3, 6, 7, 8, 8, 8, 9, 9, 10]
    for point in 0...11 {
      let result = applyReplacementMatches(matches, to: text, insertionPoint: point)
      #expect(result.text == "😀LONG x Z")
      #expect(result.insertionPoint == expected[point])
    }
  }

}
