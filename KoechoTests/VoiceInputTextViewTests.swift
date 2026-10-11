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

  @Test func replaceTextClearsPreviousVolatileRange() {
    let textView = makeTextView()
    textView.replaceText("after")
    textView.setVolatileText(" voice", at: 5)

    textView.replaceText("restored")

    #expect(textView.string == "restored")
    #expect(textView.volatileRange == nil)
    #expect(textView.finalizedString == "restored")
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

  @Test func replaceTextSelectingClearsPreviousVolatileRange() {
    let textView = makeTextView()
    textView.replaceText("after")
    textView.setVolatileText(" voice", at: 5)

    textView.replaceText("restored", selecting: NSRange(location: 3, length: 0))

    #expect(textView.string == "restored")
    #expect(textView.volatileRange == nil)
    #expect(textView.finalizedString == "restored")
    #expect(textView.selectedRange() == NSRange(location: 3, length: 0))
  }

  @Test func completedSelectionRangesNotifyCursorOnceAfterDrag() {
    let textView = makeTextView()
    textView.string = "😀hello"
    var positions: [Int] = []
    textView.onCursorMoved = { positions.append($0) }
    let selection = NSValue(range: NSRange(location: 2, length: 0))

    textView.setSelectedRanges([selection], affinity: .downstream, stillSelecting: true)
    #expect(positions.isEmpty)

    textView.setSelectedRanges([selection], affinity: .downstream, stillSelecting: false)
    #expect(positions == [2])
  }

  @Test func singleSelectionRangeStillNotifiesCursorOnce() {
    let textView = makeTextView()
    textView.string = "hello"
    var positions: [Int] = []
    textView.onCursorMoved = { positions.append($0) }

    textView.setSelectedRange(
      NSRange(location: 3, length: 0), affinity: .downstream, stillSelecting: false)

    #expect(positions == [3])
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

  @Test func setVolatileTextWithEmptyStringAfterVolatileClearsVolatile() {
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
    textView.onVolatileFinalized = {
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

  @Test func setVolatileTextClampsToStorageLength() {
    let textView = makeTextView()
    textView.string = "hi"

    // Insert at position beyond text length — should clamp
    textView.setVolatileText(" there", at: 100)

    #expect(textView.string == "hi there")
    #expect(textView.volatileRange == NSRange(location: 2, length: 6))
  }

  @Test(arguments: [0, 1, 2, 3])
  func contextMenuPrependsEligibleActionsAndPreservesStandardItems(scenario: Int) throws {
    let textView = makeTextView()
    textView.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
    let window = NSWindow(
      contentRect: textView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = textView
    defer { window.contentView = nil }
    textView.replaceText("a Z")
    let selection = NSRange(
      location: scenario == 3 ? 2 : 0, length: scenario == 1 || scenario == 2 ? 3 : 0)
    textView.setSelectedRange(selection)
    let candidates = findReplacementCandidates(
      [ReplacementRule(pattern: "a", replacement: "long")], in: textView.string)
    var selectedTargets: [ReplacementMatch]?
    textView.showReplacementCandidates(candidates) { selectedTargets = $0 }
    let manager = try #require(textView.layoutManager)
    let container = try #require(textView.textContainer)
    manager.ensureLayout(for: container)
    let characterRange = NSRange(location: scenario == 1 || scenario == 3 ? 2 : 0, length: 1)
    let glyphRange = manager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
    let rect = manager.boundingRect(forGlyphRange: glyphRange, in: container)
    let point = textView.convert(NSPoint(
      x: rect.midX + textView.textContainerOrigin.x,
      y: rect.midY + textView.textContainerOrigin.y), to: nil)
    let event = try #require(NSEvent.mouseEvent(
      with: .rightMouseDown, location: point, modifierFlags: [], timestamp: 0,
      windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    let standardView = NSTextView(frame: textView.frame)
    standardView.isRichText = false
    standardView.allowsUndo = true
    standardView.string = textView.string
    standardView.setSelectedRange(selection)
    let standardMenu = try #require(standardView.menu(for: event))
    let menu = try #require(textView.menu(for: event))
    let replaceTitle = scenario == 1 || scenario == 2 ? String(localized: "Replace Selection") : String(localized: "Replace This Occurrence")
    let addTitle = String(localized: "Add Replacement Rule\u{2026}")
    let expectedTitles: [String] = switch scenario {
    case 0: [replaceTitle]
    case 1: [replaceTitle, addTitle]
    case 2: [replaceTitle, addTitle]
    default: []
    }
    #expect(Array(menu.items.prefix(expectedTitles.count)).map(\.title) == expectedTitles)
    if scenario != 3 {
      let item = try #require(menu.items.first)
      _ = NSApp.sendAction(try #require(item.action), to: item.target, from: item)
      #expect(selectedTargets == candidates)
    }

    #expect(menu.items.filter { $0.title == replaceTitle }.count == (scenario != 3 ? 1 : 0))
    #expect(menu.items.filter { $0.title == addTitle }.count == (scenario == 1 || scenario == 2 ? 1 : 0))
    let boundaryCount = !expectedTitles.isEmpty && !standardMenu.items.isEmpty
      && !standardMenu.items[0].isSeparatorItem ? 1 : 0
    if boundaryCount == 1 {
      #expect(menu.items[expectedTitles.count].isSeparatorItem)
    }
    let standardSuffix = Array(menu.items.dropFirst(expectedTitles.count + boundaryCount))
    #expect(standardSuffix.map(\.title) == standardMenu.items.map(\.title))
    #expect(standardSuffix.map(\.action) == standardMenu.items.map(\.action))
    #expect(standardSuffix.map(\.isSeparatorItem) == standardMenu.items.map(\.isSeparatorItem))
  }

  @Test func candidateMenuHitsCurrentGlyphAndVolatileClearsItsAction() throws {
    let textView = makeTextView()
    textView.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
    let window = NSWindow(
      contentRect: textView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = textView
    defer { window.contentView = nil }
    textView.replaceText("a aZ")
    textView.setSelectedRange(NSRange(location: 0, length: 0))
    let candidates = findReplacementCandidates(
      [ReplacementRule(pattern: "a", replacement: "long")], in: textView.string)
    var selected: [ReplacementMatch]?
    textView.showReplacementCandidates(candidates) { selected = $0 }
    let manager = try #require(textView.layoutManager)
    let container = try #require(textView.textContainer)
    manager.ensureLayout(for: container)
    // Derive the event from the live glyph geometry, without fixed text coordinates.
    let glyphRange = manager.glyphRange(forCharacterRange: candidates[1].range, actualCharacterRange: nil)
    let rect = manager.boundingRect(forGlyphRange: glyphRange, in: container)
    let point = textView.convert(NSPoint(
      x: rect.midX + textView.textContainerOrigin.x,
      y: rect.midY + textView.textContainerOrigin.y), to: nil)
    let event = try #require(NSEvent.mouseEvent(
      with: .rightMouseDown, location: point, modifierFlags: [], timestamp: 0,
      windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    let menu = try #require(textView.menu(for: event))
    let item = try #require(menu.items.first {
      $0.title == String(localized: "Replace This Occurrence")
    })
    _ = NSApp.sendAction(try #require(item.action), to: item.target, from: item)
    #expect(selected == [candidates[1]])
    #expect(textView.string == "a aZ")
    textView.setVolatileText("voice", at: 3)
    #expect(textView.menu(for: event)?.items.contains {
      $0.title == String(localized: "Replace This Occurrence")
    } == false)
    textView.clearVolatileText()
    // Clearing volatile alone cannot revive a cleared candidate callback.
    #expect(textView.menu(for: event)?.items.contains {
      $0.title == String(localized: "Replace This Occurrence")
    } == false)
  }

  @Test func caretStopRechecksSnapshotAndRejectsCancelledReservations() throws {
    let preview = CaretReplacementPreview()
    let first = CaretReplacementPreview.Snapshot(
      text: "a", caret: 0, match: .init(range: NSRange(location: 0, length: 1), replacement: "long"))
    var current: CaretReplacementPreview.Snapshot? = first
    preview.update(first, current: { current }, onChange: {})
    let stale = try #require(preview.timer)
    preview.cancel()
    stale.fire()
    #expect(preview.displayed == nil)
    preview.update(first, current: { current }, onChange: {})
    current = nil
    try #require(preview.timer).fire()
    #expect(preview.displayed == nil)
    current = first
    preview.update(first, current: { current }, onChange: {})
    let reservation = try #require(preview.timer)
    preview.update(first, current: { current }, onChange: {})
    #expect(preview.timer === reservation)
    reservation.fire()
    #expect(preview.displayed?.label == "a → long")
    preview.update(nil, current: { nil }, onChange: {})
    #expect(preview.displayed == nil)
  }

  @Test func caretPreviewUsesManualCandidateContentAndEarlierAdjacentBoundary() throws {
    let view = makeTextView()
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
    let window = CaretPreviewWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    defer { window.orderOut(nil); window.contentView = nil }
    let cases: [(String, [ReplacementRule], Int, String)] = [
      ("ab", [.init(pattern: "a", replacement: "long"), .init(pattern: "b", replacement: "B")], 1, "a → long"),
      ("long", [.init(pattern: "long", replacement: "x")], 4, "long → x"),
      ("delete", [.init(pattern: "delete", replacement: "")], 0, "delete → ∅"),
      ("item42", [.init(pattern: "item([0-9]+)", replacement: "$1", usesRegularExpression: true)], 3, "item42 → 42"),
      ("a", [.init(pattern: "a", replacement: "b"), .init(pattern: "b", replacement: "c")], 1, "a → b")
    ]
    for (text, rules, caret, label) in cases {
      view.replaceText(text, selecting: NSRange(location: caret, length: 0))
      view.showReplacementCandidates(findReplacementCandidates(rules, in: text), rules: rules) { _ in }
      try #require(view.caretReplacementPreview.timer).fire()
      #expect(view.caretReplacementPreview.displayed?.label == label)
      #expect(view.string == text)
      #expect(view.selectedRange() == NSRange(location: caret, length: 0))
      #expect(window.firstResponder === view)
    }
  }

  @Test(arguments: Array(0...12), [false, true])
  func caretPreviewCancelsForInputLifecycleAndStartsFresh(scenario: Int, wasDisplayed: Bool) throws {
    let view = makeTextView()
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
    let window = CaretPreviewWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    defer { window.orderOut(nil); window.contentView = nil }
    let rules = [ReplacementRule(pattern: "a", replacement: "long")]
    let candidates = findReplacementCandidates(rules, in: "ab")
    view.replaceText("a b", selecting: NSRange(location: 0, length: 0))
    view.showReplacementCandidates(candidates, rules: rules) { _ in }
    let old = try #require(view.caretReplacementPreview.timer)
    if wasDisplayed { old.fire() }
    #expect((view.caretReplacementPreview.displayed != nil) == wasDisplayed)
    switch scenario {
    case 0: _ = view.shouldChangeText(in: NSRange(location: 0, length: 0), replacementString: "x")
    case 1: view.setSelectedRange(NSRange(location: 2, length: 0))
    case 2: view.setSelectedRange(NSRange(location: 0, length: 1))
    case 3:
      view.setSelectedRanges([NSValue(range: NSRange(location: 0, length: 1)),
                              NSValue(range: NSRange(location: 2, length: 1))],
                             affinity: .downstream, stillSelecting: false)
      #expect(view.selectedRanges.count == 2)
    case 4: view.replaceText("changed")
    case 5:
      var changed = rules
      changed[0].matchesWholeWord = true
      // The candidate array is deliberately unchanged: rules alone invalidate the interval.
      view.showReplacementCandidates(candidates, rules: changed) { _ in }
    case 6: view.showReplacementPreviews(candidates)
    case 7: view.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
    case 8: view.setVolatileText("voice", at: 2)
    case 9: window.makeFirstResponder(nil)
    case 10: view.isHidden = true
    case 11:
      // The panel controller clears previews before ordering its window out.
      view.clearReplacementPreviews()
      window.orderOut(nil)
    default:
      window.previewIsKey = false
      NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
    }
    old.fire()
    #expect(view.caretReplacementPreview.displayed == nil)
    if scenario == 5 { #expect(view.caretReplacementPreview.timer != nil) }
    else { #expect(view.caretReplacementPreview.timer == nil) }
    view.commitMarkedTextIfNeeded()
    view.isHidden = false
    window.previewIsKey = true
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    view.replaceText("ab", selecting: NSRange(location: 0, length: 0))
    view.showReplacementCandidates(candidates, rules: rules) { _ in }
    let fresh = try #require(view.caretReplacementPreview.timer)
    #expect(fresh !== old)
    fresh.fire()
    #expect(view.caretReplacementPreview.displayed?.label == "a → long")
  }

}

// Hosted tests suppress app activation; supply only the OS key-window signal.
// The text view, first-responder transitions, snapshot selection and timers remain real.
@MainActor
private final class CaretPreviewWindow: NSWindow {
  var previewIsKey = true
  override var isKeyWindow: Bool { previewIsKey }
}
