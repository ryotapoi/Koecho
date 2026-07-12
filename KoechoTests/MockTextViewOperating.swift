import AppKit
import KoechoCore

@testable import Koecho

@MainActor
final class MockTextViewOperating: TextViewOperating {
  var string: String = ""
  var finalizedString: String = ""
  var volatileRange: NSRange?

  var markedText = false
  func hasMarkedText() -> Bool { markedText }

  var replaceTextCalls: [String] = []
  func replaceText(_ text: String) {
    replaceTextCalls.append(text)
    string = text
    finalizedString = text
  }

  var insertFinalizedTextCalls: [(text: String, position: Int)] = []
  var insertFinalizedTextResult: String?
  func insertFinalizedText(_ text: String, at position: Int) -> String {
    insertFinalizedTextCalls.append((text, position))
    let insertedText = insertFinalizedTextResult ?? text
    let mutableString = NSMutableString(string: string)
    let clampedPosition = min(position, mutableString.length)
    mutableString.insert(insertedText, at: clampedPosition)
    string = mutableString as String
    finalizedString = string
    return insertedText
  }

  var setVolatileTextCalls: [(text: String, position: Int)] = []
  func setVolatileText(_ text: String, at position: Int) {
    setVolatileTextCalls.append((text, position))
  }

  var clearVolatileTextCallCount = 0
  func clearVolatileText() {
    clearVolatileTextCallCount += 1
    volatileRange = nil
  }

  var finalizeVolatileTextCallCount = 0
  func finalizeVolatileText() {
    finalizeVolatileTextCallCount += 1
    volatileRange = nil
  }

  var showReplacementPreviewsCalls: [[ReplacementMatch]] = []
  func showReplacementPreviews(_ matches: [ReplacementMatch]) {
    showReplacementPreviewsCalls.append(matches)
  }

  var clearReplacementPreviewsCallCount = 0
  func clearReplacementPreviews() {
    clearReplacementPreviewsCallCount += 1
  }

  var makeFirstResponderCallCount = 0
  func makeFirstResponder(in panel: InputPanel) {
    makeFirstResponderCallCount += 1
  }

  var setSelectedRangeCalls: [NSRange] = []
  func setSelectedRange(_ range: NSRange) {
    setSelectedRangeCalls.append(range)
  }

  var selectedRangeValue = NSRange(location: 0, length: 0)
  func selectedRange() -> NSRange { selectedRangeValue }

  var scrollRangeToVisibleCalls: [NSRange] = []
  func scrollRangeToVisible(_ range: NSRange) {
    scrollRangeToVisibleCalls.append(range)
  }
}
