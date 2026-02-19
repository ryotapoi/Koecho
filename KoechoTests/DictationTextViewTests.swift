import AppKit
import Testing
@testable import Koecho

@MainActor
@Suite(.serialized)
struct DictationTextViewTests {
    private func makeTextView() -> DictationTextView {
        let textView = DictationTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        return textView
    }

    @Test func didChangeTextFiresOnTextChanged() {
        let textView = makeTextView()
        var receivedText: String?
        textView.onTextChanged = { text in
            receivedText = text
        }

        textView.string = "hello"
        textView.didChangeText()

        #expect(receivedText == "hello")
    }

    @Test func didChangeTextSkipsWhenSuppressed() {
        let textView = makeTextView()

        var callCount = 0
        textView.onTextChanged = { _ in
            callCount += 1
        }

        textView.isSuppressingCallbacks = true
        textView.string = "hello"
        textView.didChangeText()

        #expect(callCount == 0)
    }

    @Test func insertTextFiresOnTextCommitted() {
        let textView = makeTextView()
        textView.textContainer?.widthTracksTextView = true

        var committed = false
        textView.onTextCommitted = {
            committed = true
        }

        textView.insertText("hello", replacementRange: NSRange(location: 0, length: 0))

        #expect(committed == true)
    }

    @Test func addReplacementRuleCallbackWithSelectedText() {
        let textView = makeTextView()
        textView.string = "hello world"
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        var receivedPattern: String?
        textView.onAddReplacementRule = { pattern in
            receivedPattern = pattern
        }

        // Invoke the menu action directly via the selector
        textView.perform(Selector(("addReplacementRuleFromMenu:")), with: nil)

        #expect(receivedPattern == "hello")
    }

    @Test func addReplacementRuleCallbackWithNoSelection() {
        let textView = makeTextView()
        textView.string = "hello world"
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        var receivedPattern: String?
        textView.onAddReplacementRule = { pattern in
            receivedPattern = pattern
        }

        textView.perform(Selector(("addReplacementRuleFromMenu:")), with: nil)

        #expect(receivedPattern == nil)
    }
}
