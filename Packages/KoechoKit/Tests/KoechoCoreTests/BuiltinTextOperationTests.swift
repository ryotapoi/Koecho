import Foundation
import KoechoCore
import Testing

struct BuiltinTextOperationTests {
  private let increase = BuiltinScript(feature: .increaseIndent, indentationWidth: .two)!
  private let increaseFour = BuiltinScript(feature: .increaseIndent, indentationWidth: .four)!
  private let decrease = BuiltinScript(feature: .decreaseIndent, indentationWidth: .two)!
  private let decreaseFour = BuiltinScript(feature: .decreaseIndent, indentationWidth: .four)!
  private let quote = BuiltinScript(feature: .blockQuote)!

  @Test func transformsIntersectingLinesAndSelectsTheirContent() {
    let result = BuiltinTextOperation.apply(
      to: "one\ntwo\nthree", selection: NSRange(location: 1, length: 5), builtin: increase)

    #expect(result.text == "  one\n  two\nthree")
    #expect(result.selection == NSRange(location: 0, length: 11))
  }

  @Test func selectionEndingAtNextLineStartExcludesThatLine() {
    let result = BuiltinTextOperation.apply(
      to: "one\ntwo", selection: NSRange(location: 0, length: 4), builtin: quote)

    #expect(result.text == "> one\ntwo")
    #expect(result.selection == NSRange(location: 0, length: 5))
  }

  @Test func cursorTargetsItsLineIncludingEmptyFinalLine() {
    let result = BuiltinTextOperation.apply(
      to: "one\n", selection: NSRange(location: 4, length: 0), builtin: increase)

    #expect(result.text == "one\n  ")
    #expect(result.selection == NSRange(location: 4, length: 2))
  }

  @Test func preservesUnicodeUTF16Offsets() {
    let result = BuiltinTextOperation.apply(
      to: "😀one\n二", selection: NSRange(location: 2, length: 3), builtin: increaseFour)

    #expect(result.text == "    😀one\n二")
    #expect(result.selection == NSRange(location: 0, length: 9))
  }

  @Test func decreaseRemovesOnlyAvailableLeadingSpacesAtConfiguredWidth() {
    let two = BuiltinTextOperation.apply(
      to: " a\n    b", selection: NSRange(location: 0, length: 7), builtin: decrease)
    let four = BuiltinTextOperation.apply(
      to: "  a", selection: NSRange(location: 0, length: 0), builtin: decreaseFour)

    #expect(two.text == "a\n  b")
    #expect(four.text == "a")
  }

  @Test func quotePrefixesBlankAndNestedQuotedLinesEveryTime() {
    let once = BuiltinTextOperation.apply(
      to: "> one\n\n", selection: NSRange(location: 0, length: 7), builtin: quote)
    let twice = BuiltinTextOperation.apply(to: once.text, selection: once.selection, builtin: quote)

    #expect(once.text == "> > one\n> \n")
    #expect(once.selection == NSRange(location: 0, length: 10))
    #expect(twice.text == "> > > one\n> > \n")
    #expect(twice.selection == NSRange(location: 0, length: 14))
  }

  @Test func handlesEmptyDocumentAndPreservesDocumentBoundaryWhitespace() {
    let empty = BuiltinTextOperation.apply(
      to: "", selection: NSRange(location: 0, length: 0), builtin: quote)
    let spaced = BuiltinTextOperation.apply(
      to: "  one  ", selection: NSRange(location: 0, length: 0), builtin: increase)

    #expect(empty.text == "> ")
    #expect(empty.selection == NSRange(location: 0, length: 2))
    #expect(spaced.text == "    one  ")
  }
}
