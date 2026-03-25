import Foundation
import Testing
@testable import KoechoCore

@MainActor
struct ReplacementRuleTests {
    // MARK: - Plain text search

    @Test func plainTextReplacement() {
        let rules = [
            ReplacementRule(pattern: "えーと", replacement: ""),
        ]
        let result = applyReplacementRules(rules, to: "えーと今日はえーと天気がいいです")
        #expect(result == "今日は天気がいいです")
    }

    @Test func plainTextMatchWholeWordOn() {
        let rules = [
            ReplacementRule(pattern: "the", replacement: "a", matchesWholeWord: true),
        ]
        let result = applyReplacementRules(rules, to: "the other the")
        #expect(result == "a other a")
    }

    @Test func plainTextMatchWholeWordOff() {
        let rules = [
            ReplacementRule(pattern: "the", replacement: "X"),
        ]
        let result = applyReplacementRules(rules, to: "the other the")
        #expect(result == "X oXr X")
    }

    // MARK: - Regex mode

    @Test func regexBasicReplacement() {
        let rules = [
            ReplacementRule(pattern: "\\s+", replacement: " ", usesRegularExpression: true),
        ]
        let result = applyReplacementRules(rules, to: "hello   world\t\tfoo")
        #expect(result == "hello world foo")
    }

    @Test func regexCaptureGroups() {
        let rules = [
            ReplacementRule(pattern: "(\\w+) (\\w+)", replacement: "$2 $1", usesRegularExpression: true),
        ]
        let result = applyReplacementRules(rules, to: "hello world")
        #expect(result == "world hello")
    }

    @Test func regexInvalidPatternSkipped() {
        let rules = [
            ReplacementRule(pattern: "[invalid", replacement: "x", usesRegularExpression: true),
        ]
        let result = applyReplacementRules(rules, to: "hello")
        #expect(result == "hello")
    }

    // MARK: - Plain text with regex metacharacters

    @Test func plainTextEscapesMetacharacters() {
        let rules = [
            ReplacementRule(pattern: "$100", replacement: "100 dollars"),
        ]
        let result = applyReplacementRules(rules, to: "Price is $100 today")
        #expect(result == "Price is 100 dollars today")
    }

    @Test func plainTextEscapesDot() {
        let rules = [
            ReplacementRule(pattern: "file.txt", replacement: "document.txt"),
        ]
        let result = applyReplacementRules(rules, to: "Open file.txt now")
        #expect(result == "Open document.txt now")
    }

    @Test func plainTextReplacementWithDollarSign() {
        let rules = [
            ReplacementRule(pattern: "price", replacement: "$100"),
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

    // MARK: - Skip conditions

    @Test func emptyPatternSkipped() {
        let rules = [
            ReplacementRule(pattern: "", replacement: "x"),
        ]
        let result = applyReplacementRules(rules, to: "hello")
        #expect(result == "hello")
    }

    // MARK: - Edge cases

    @Test func emptyInputText() {
        let rules = [
            ReplacementRule(pattern: "hello", replacement: "bye"),
        ]
        let result = applyReplacementRules(rules, to: "")
        #expect(result == "")
    }

    @Test func replacementResultsInEmptyString() {
        let rules = [
            ReplacementRule(pattern: ".*", replacement: "", usesRegularExpression: true),
        ]
        let result = applyReplacementRules(rules, to: "hello")
        #expect(result == "")
    }

    @Test func noRulesReturnsOriginal() {
        let result = applyReplacementRules([], to: "hello")
        #expect(result == "hello")
    }

    // MARK: - Regex mode ignores matchesWholeWord

    @Test func regexModeIgnoresMatchesWholeWord() {
        let rules = [
            ReplacementRule(
                pattern: "the",
                replacement: "X",
                usesRegularExpression: true,
                matchesWholeWord: true
            ),
        ]
        // In regex mode, matchesWholeWord is ignored so "the" inside "other" should also match
        let result = applyReplacementRules(rules, to: "the other the")
        #expect(result == "X oXr X")
    }

    // MARK: - findReplacementMatches

    @Test func findMatchesSingleRuleSingleMatch() {
        let rules = [ReplacementRule(pattern: "えーと", replacement: "")]
        let matches = findReplacementMatches(rules, in: "えーと天気")
        #expect(matches == [ReplacementMatch(range: NSRange(location: 0, length: 3), replacement: "")])
    }

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

    @Test func findMatchesRegexCaptureGroups() {
        let rules = [
            ReplacementRule(
                pattern: "(\\w+) (\\w+)",
                replacement: "$2 $1",
                usesRegularExpression: true
            ),
        ]
        let matches = findReplacementMatches(rules, in: "hello world")
        #expect(matches.count == 1)
        #expect(matches[0] == ReplacementMatch(range: NSRange(location: 0, length: 11), replacement: "world hello"))
    }

    @Test func findMatchesWholeWord() {
        let rules = [
            ReplacementRule(pattern: "the", replacement: "a", matchesWholeWord: true),
        ]
        let matches = findReplacementMatches(rules, in: "the other the")
        #expect(matches.count == 2)
        #expect(matches[0] == ReplacementMatch(range: NSRange(location: 0, length: 3), replacement: "a"))
        #expect(matches[1] == ReplacementMatch(range: NSRange(location: 10, length: 3), replacement: "a"))
    }

    @Test func findMatchesDollarSignInReplacement() {
        let rules = [ReplacementRule(pattern: "price", replacement: "$100")]
        let matches = findReplacementMatches(rules, in: "The price is here")
        #expect(matches.count == 1)
        #expect(matches[0] == ReplacementMatch(range: NSRange(location: 4, length: 5), replacement: "$100"))
    }

    @Test func findMatchesNoMatch() {
        let rules = [ReplacementRule(pattern: "xyz", replacement: "abc")]
        let matches = findReplacementMatches(rules, in: "hello world")
        #expect(matches.isEmpty)
    }

    @Test func findMatchesEmptyText() {
        let rules = [ReplacementRule(pattern: "hello", replacement: "bye")]
        let matches = findReplacementMatches(rules, in: "")
        #expect(matches.isEmpty)
    }

    @Test func findMatchesEmptyRules() {
        let matches = findReplacementMatches([], in: "hello world")
        #expect(matches.isEmpty)
    }

    // MARK: - validate

    @Test func validatePlainTextReturnsNil() {
        let rule = ReplacementRule(pattern: "hello")
        #expect(rule.validate() == nil)
    }

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
        let rule = ReplacementRule(pattern: "$100")
        #expect(rule.validate() == nil)
    }

    // MARK: - displayName

    @Test func displayNameEmptyPattern() {
        let rule = ReplacementRule(pattern: "")
        #expect(rule.displayName == nil)
    }

    @Test func displayNamePatternOnly() {
        let rule = ReplacementRule(pattern: "hello")
        #expect(rule.displayName == "hello")
    }

    @Test func displayNamePatternAndReplacement() {
        let rule = ReplacementRule(pattern: "hello", replacement: "bye")
        #expect(rule.displayName == "hello → bye")
    }

    // MARK: - Codable migration (pattern → patterns)

    @Test func decodeLegacySinglePatternFormat() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "pattern": "えーと",
            "replacement": "",
            "usesRegularExpression": false,
            "matchesWholeWord": false
        }
        """.data(using: .utf8)!
        let rule = try JSONDecoder().decode(ReplacementRule.self, from: json)
        #expect(rule.patterns == ["えーと"])
        #expect(rule.pattern == "えーと")
        #expect(rule.replacement == "")
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
        #expect(rule.patterns == ["GitHブ", "ギットHub"])
        #expect(rule.pattern == "GitHブ")
        #expect(rule.replacement == "GitHub")
    }

    @Test func encodeUsesPatternsKey() throws {
        let rule = ReplacementRule(pattern: "test", replacement: "replaced")
        let data = try JSONEncoder().encode(rule)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["patterns"] as? [String] == ["test"])
        #expect(dict["pattern"] == nil)
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
        #expect(decoded.patterns == ["a", "b"])
        #expect(decoded.replacement == "c")
        #expect(decoded.matchesWholeWord == true)
        #expect(decoded.id == rule.id)
    }

    @Test func decodeLegacyEmptyPatternFormat() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000003",
            "pattern": "",
            "replacement": "",
            "usesRegularExpression": false,
            "matchesWholeWord": false
        }
        """.data(using: .utf8)!
        let rule = try JSONDecoder().decode(ReplacementRule.self, from: json)
        #expect(rule.patterns == [""])
        #expect(rule.pattern == "")
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
        #expect(rule.patterns == [""])
    }

    // MARK: - pattern computed property

    @Test func patternComputedPropertyGetReturnsFirst() {
        let rule = ReplacementRule(patterns: ["a", "b"], replacement: "c")
        #expect(rule.pattern == "a")
    }

    @Test func patternComputedPropertySetUpdatesFirst() {
        var rule = ReplacementRule(patterns: ["a", "b"], replacement: "c")
        rule.pattern = "x"
        #expect(rule.patterns == ["x", "b"])
    }

    // MARK: - empty array prevention

    @Test func initWithEmptyPatternsArrayFallsBack() {
        let rule = ReplacementRule(patterns: [], replacement: "x")
        #expect(rule.patterns == [""])
    }

    // MARK: - displayName with all-empty patterns

    @Test func displayNameAllEmptyPatterns() {
        let rule = ReplacementRule(patterns: ["", ""], replacement: "x")
        #expect(rule.displayName == nil)
    }

    // MARK: - Multiple patterns (plain text mode)

    @Test func multiplePatternsBasicReplacement() {
        let rules = [
            ReplacementRule(patterns: ["GitHブ", "ギットHub"], replacement: "GitHub"),
        ]
        let result = applyReplacementRules(rules, to: "GitHブとギットHubを使う")
        #expect(result == "GitHubとGitHubを使う")
    }

    @Test func multiplePatternsLongestMatchFirst() {
        // "GitHub" should match before "Git" due to longest-first sorting
        let rules = [
            ReplacementRule(patterns: ["Git", "GitHub"], replacement: "X"),
        ]
        let result = applyReplacementRules(rules, to: "GitHub is great")
        #expect(result == "X is great")
    }

    @Test func multiplePatternsWithEmptyElement() {
        // Empty patterns should be filtered out
        let rules = [
            ReplacementRule(patterns: ["", "foo", ""], replacement: "bar"),
        ]
        let result = applyReplacementRules(rules, to: "foo and foo")
        #expect(result == "bar and bar")
    }

    @Test func multiplePatternsAllEmpty() {
        let rules = [
            ReplacementRule(patterns: ["", ""], replacement: "x"),
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
            ),
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
            ),
        ]
        let result = applyReplacementRules(rules, to: "abc 123 ignored")
        #expect(result == "abc N ignored")
    }

    // MARK: - findReplacementMatches with multiple patterns

    @Test func findMatchesMultiplePatterns() {
        let rules = [
            ReplacementRule(patterns: ["GitHブ", "ギットHub"], replacement: "GitHub"),
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
}
