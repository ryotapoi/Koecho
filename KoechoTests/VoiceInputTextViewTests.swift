import AppKit
import KoechoCore
import Testing

@testable import Koecho

@MainActor
@Suite(.serialized)
struct VoiceInputTextViewTests {
  private func makeTextView() -> VoiceInputTextView {
    let textView = VoiceInputTextView()
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

  @Test func replaceTextDoesNotFireOnTextChanged() {
    let textView = makeTextView()

    var callCount = 0
    textView.onTextChanged = { _ in
      callCount += 1
    }

    textView.replaceText("hello")

    #expect(textView.string == "hello")
    #expect(callCount == 0)
  }

  @Test func replaceTextSelectingUpdatesTextSelectionAndScrollWithoutCallbacks() {
    let textView = makeTextView()
    var textChanged = 0
    var cursorMoved = 0
    textView.onTextChanged = { _ in textChanged += 1 }
    textView.onCursorMoved = { _ in cursorMoved += 1 }

    textView.replaceText("😀one", selecting: NSRange(location: 2, length: 3))

    #expect(textView.string == "😀one")
    #expect(textView.selectedRange() == NSRange(location: 2, length: 3))
    #expect(textChanged == 0)
    #expect(cursorMoved == 0)
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

  @Test func commitMarkedTextKeepsJapaneseComposition() {
    let textView = makeTextView()
    textView.setMarkedText(
      "こんにちは",
      selectedRange: NSRange(location: 5, length: 0),
      replacementRange: NSRange(location: NSNotFound, length: 0)
    )

    textView.commitMarkedTextIfNeeded()

    #expect(textView.hasMarkedText() == false)
    #expect(textView.string == "こんにちは")
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

  // MARK: - Volatile text tests

  @Test func setVolatileTextInsertsAtPosition() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)

    #expect(textView.string == "hello world")
    #expect(textView.volatileRange == NSRange(location: 5, length: 6))
  }

  @Test func setVolatileTextAtBeginning() {
    let textView = makeTextView()
    textView.string = "world"

    textView.setVolatileText("hello ", at: 0)

    #expect(textView.string == "hello world")
    #expect(textView.volatileRange == NSRange(location: 0, length: 6))
  }

  @Test func setVolatileTextRemovesDuplicateLeadingPunctuation() {
    let textView = makeTextView()
    textView.string = "hello."

    textView.setVolatileText(". world", at: 6)

    #expect(textView.string == "hello. world")
    #expect(textView.volatileRange == NSRange(location: 6, length: 6))
  }

  @Test func setVolatileTextReplacesExisting() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)
    textView.setVolatileText(" earth", at: 5)

    #expect(textView.string == "hello earth")
    #expect(textView.volatileRange == NSRange(location: 5, length: 6))
  }

  @Test func clearVolatileTextRemovesText() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)
    #expect(textView.string == "hello world")

    textView.clearVolatileText()
    #expect(textView.string == "hello")
    #expect(textView.volatileRange == nil)
  }

  @Test func clearVolatileTextWhenNoneIsNoop() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.clearVolatileText()

    #expect(textView.string == "hello")
    #expect(textView.volatileRange == nil)
  }

  @Test func finalizeVolatileTextKeepsTextClearsRange() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)
    textView.finalizeVolatileText()

    #expect(textView.string == "hello world")
    #expect(textView.volatileRange == nil)
  }

  @Test func finalizedStringExcludesVolatile() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)

    #expect(textView.finalizedString == "hello")
  }

  @Test func finalizedStringWithNoVolatile() {
    let textView = makeTextView()
    textView.string = "hello world"

    #expect(textView.finalizedString == "hello world")
  }

  @Test func setVolatileTextWithEmptyStringAfterVolatileClearsVolatile() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)
    textView.setVolatileText("", at: 5)

    #expect(textView.string == "hello")
    #expect(textView.volatileRange == nil)
  }

  @Test func setVolatileTextWithEmptyStringClearsVolatile() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)
    textView.setVolatileText("", at: 5)

    #expect(textView.string == "hello")
    #expect(textView.volatileRange == nil)
  }

  @Test func volatileTextDoesNotFireCallbacks() {
    let textView = makeTextView()
    textView.string = "hello"

    var callCount = 0
    textView.onTextChanged = { _ in callCount += 1 }

    textView.setVolatileText(" world", at: 5)
    textView.clearVolatileText()
    textView.setVolatileText(" earth", at: 5)
    textView.finalizeVolatileText()

    #expect(callCount == 0)
  }

  @Test func volatileTextInMiddle() {
    let textView = makeTextView()
    textView.string = "hello world"

    textView.setVolatileText("beautiful ", at: 6)

    #expect(textView.string == "hello beautiful world")
    #expect(textView.finalizedString == "hello world")
    #expect(textView.volatileRange == NSRange(location: 6, length: 10))
  }

  // MARK: - Finalized text insertion

  @Test func insertFinalizedTextInsertsAtClampedPositionWithoutCallbacks() {
    let textView = makeTextView()
    textView.string = "hi"
    var callCount = 0
    textView.onTextChanged = { _ in callCount += 1 }

    let insertedText = textView.insertFinalizedText(" there", at: 100)

    #expect(insertedText == " there")
    #expect(textView.string == "hi there")
    #expect(callCount == 0)
  }

  @Test func insertFinalizedTextRemovesDuplicateLeadingPunctuation() {
    let textView = makeTextView()
    textView.string = "hello."

    let insertedText = textView.insertFinalizedText(". world", at: 6)

    #expect(insertedText == " world")
    #expect(textView.string == "hello. world")
  }

  @Test func insertFinalizedTextKeepsDuplicateNonPunctuation() {
    let textView = makeTextView()
    textView.string = "hello"

    let insertedText = textView.insertFinalizedText("o world", at: 5)

    #expect(insertedText == "o world")
    #expect(textView.string == "helloo world")
  }

  // MARK: - Edge case tests

  @Test func shouldChangeTextFinalizesVolatile() {
    let textView = makeTextView()
    textView.string = "hello"
    textView.setVolatileText(" world", at: 5)

    var finalizeCalled = false
    textView.onVolatileFinalized = { _ in
      finalizeCalled = true
    }

    // Simulate keyboard input triggering shouldChangeText
    _ = textView.shouldChangeText(
      in: NSRange(location: 11, length: 0),
      replacementString: "!"
    )

    #expect(textView.volatileRange == nil)
    // Volatile text is finalized (kept as confirmed text)
    #expect(textView.string == "hello world")
    #expect(finalizeCalled)
  }

  @Test func shouldChangeTextNoOpWhenNoVolatile() {
    let textView = makeTextView()
    textView.string = "hello"

    let result = textView.shouldChangeText(
      in: NSRange(location: 5, length: 0),
      replacementString: "!"
    )

    #expect(result == true)
    #expect(textView.string == "hello")
  }

  @Test func setVolatileTextClampsToStorageLength() {
    let textView = makeTextView()
    textView.string = "hi"

    // Insert at position beyond text length — should clamp
    textView.setVolatileText(" there", at: 100)

    #expect(textView.string == "hi there")
    #expect(textView.volatileRange == NSRange(location: 2, length: 6))
  }

  @Test func clearVolatileTextWithCorruptedRange() {
    let textView = makeTextView()
    textView.string = "hello"

    textView.setVolatileText(" world", at: 5)
    // Simulate external modification that corrupts the range
    textView.textStorage?.replaceCharacters(in: NSRange(location: 0, length: 11), with: "hi")

    // Should safely handle out-of-bounds range
    textView.clearVolatileText()
    #expect(textView.volatileRange == nil)
  }
}
