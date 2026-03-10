import AppKit
import KoechoCore
@testable import Koecho

@MainActor
final class MockTextViewOperating: TextViewOperating {
    var string: String = ""
    var finalizedString: String = ""
    var volatileRange: NSRange?
    var textStorage: NSTextStorage? = NSTextStorage()
    var typingAttributes: [NSAttributedString.Key: Any] = [:]
    var isSuppressingCallbacks = false

    var markedText = false
    func hasMarkedText() -> Bool { markedText }

    var setStringCalls: [(text: String, suppressing: Bool)] = []
    func setString(_ text: String, suppressingCallbacks: Bool) {
        setStringCalls.append((text, suppressingCallbacks))
        string = text
        finalizedString = text
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
