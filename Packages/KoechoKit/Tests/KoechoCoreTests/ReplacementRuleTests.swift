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
        #expect(rule.displayName == "New Rule")
    }

    @Test func displayNamePatternOnly() {
        let rule = ReplacementRule(pattern: "hello")
        #expect(rule.displayName == "hello")
    }

    @Test func displayNamePatternAndReplacement() {
        let rule = ReplacementRule(pattern: "hello", replacement: "bye")
        #expect(rule.displayName == "hello → bye")
    }
}
