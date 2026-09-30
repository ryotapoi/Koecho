import AppKit
import KoechoCore

@testable import Koecho

@MainActor
final class MockTextViewOperating: TextViewOperating {
  var string: String = ""
  var finalizedString: String {
    get {
      onReadFinalizedString?()
      return storedFinalizedString
    }
    set { storedFinalizedString = newValue }
  }
  private var storedFinalizedString = ""
  var onReadFinalizedString: (() -> Void)?
  var volatileRange: NSRange?

  var markedText = false
  func hasMarkedText() -> Bool { markedText }

  var replaceTextCalls: [String] = []
  func replaceText(_ text: String) {
    replaceTextCalls.append(text)
    string = text
    finalizedString = text
  }

  var replaceTextSelectingCalls: [(text: String, range: NSRange)] = []
  func replaceText(_ text: String, selecting range: NSRange) {
    replaceTextSelectingCalls.append((text, range))
    string = text
    finalizedString = text
    selectedRangeValue = range
  }

  var insertFinalizedTextCalls: [(text: String, position: Int)] = []
  func insertFinalizedText(_ text: String, at position: Int) -> String {
    insertFinalizedTextCalls.append((text, position))
    let mutableString = NSMutableString(string: string)
    let clampedPosition = min(position, mutableString.length)
    mutableString.insert(text, at: clampedPosition)
    string = mutableString as String
    finalizedString = string
    return text
  }

  var setVolatileTextCalls: [(text: String, position: Int)] = []
  func setVolatileText(_ text: String, at position: Int) {
    setVolatileTextCalls.append((text, position))
  }

  var clearVolatileTextCallCount = 0
  var onClearVolatileText: (() -> Void)?
  func clearVolatileText() {
    clearVolatileTextCallCount += 1
    volatileRange = nil
    onClearVolatileText?()
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

  func makeFirstResponder(in panel: InputPanel) {}

  func setSelectedRange(_ range: NSRange) {}

  var selectedRangeValue = NSRange(location: 0, length: 0)
  func selectedRange() -> NSRange { selectedRangeValue }

  func scrollRangeToVisible(_ range: NSRange) {}
}
