import Foundation
import Testing
@testable import Koecho

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
