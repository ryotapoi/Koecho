import AppKit
import KoechoCore

final class VoiceInputTextView: NSTextView, TextViewOperating {
  var onTextChanged: ((String) -> Void)?
  var onTextCommitted: (() -> Void)?
  var onAddReplacementRule: ((String) -> Void)?
  var onCursorMoved: ((Int) -> Void)?
  /// Called when volatile text is finalized by keyboard input.
  /// The parameter is the volatile text that was finalized.
  var onVolatileFinalized: ((String) -> Void)?

  /// Programmatic storage edits must not flow back through `onTextChanged`.
  /// Keep this state private so every storage mutation uses the same guard.
  private var isSuppressingCallbacks = false

  /// SpeechAnalyzer mode: range of volatile (unconfirmed) text in the text storage.
  private(set) var volatileRange: NSRange?

  /// Replacement preview data drawn as underlines in `draw(_:)`.
  /// Subviews must not be added during IME composition — doing so corrupts
  /// the marked text state and causes duplicate text.
  private var previewMatches: [ReplacementMatch] = []

  var onDisplayTextChanged: (() -> Void)?
  private var onReplaceCandidate: ((ReplacementMatch) -> Void)?

  // MARK: - TextViewOperating

  /// Commits an active IME composition before an operation that may discard it.
  func commitMarkedTextIfNeeded() {
    guard hasMarkedText() else { return }
    unmarkText()
  }

  func replaceText(_ text: String) {
    suppressCallbacks {
      clearVolatileText()
      string = text
    }
    onDisplayTextChanged?()
  }

  /// Replace the document and its selected result as one suppressed UI update.
  func replaceText(_ text: String, selecting range: NSRange) {
    suppressCallbacks {
      clearVolatileText()
      string = text
      let length = (text as NSString).length
      let location = max(0, min(range.location, length))
      let selection = NSRange(location: location, length: max(0, min(range.length, length - location)))
      setSelectedRange(selection)
      scrollRangeToVisible(selection)
    }
    onDisplayTextChanged?()
  }

  @discardableResult
  func insertFinalizedText(_ text: String, at position: Int) -> String {
    guard let storage = textStorage else { return "" }
    let clampedPoint = min(position, storage.length)
    let adjustedText = removingDuplicateLeadingPunctuation(text, at: clampedPoint)
    guard !adjustedText.isEmpty else { return "" }

    suppressCallbacks {
      storage.beginEditing()
      storage.insert(
        NSAttributedString(string: adjustedText, attributes: typingAttributes),
        at: clampedPoint
      )
      storage.endEditing()
    }
    return adjustedText
  }

  func makeFirstResponder(in panel: InputPanel) {
    panel.makeFirstResponder(self)
  }

  // MARK: - Volatile text

  /// Set volatile text at the given insertion point (UTF-16 offset).
  /// Replaces any previous volatile text.
  func setVolatileText(_ text: String, at insertionPoint: Int) {
    clearVolatileText()
    let storage = textStorage!
    let clampedPoint = min(insertionPoint, storage.length)
    let adjustedText = removingDuplicateLeadingPunctuation(text, at: clampedPoint)
    guard !adjustedText.isEmpty else { return }
    clearReplacementPreviews()
    let nsText = adjustedText as NSString

    suppressCallbacks {
      storage.beginEditing()
      storage.insert(
        NSAttributedString(string: adjustedText, attributes: typingAttributes), at: clampedPoint)
      storage.endEditing()
    }

    let range = NSRange(location: clampedPoint, length: nsText.length)
    volatileRange = range
    applyVolatileStyling(range)
  }

  /// Remove volatile text from the text storage.
  func clearVolatileText() {
    guard let range = volatileRange else { return }
    let storage = textStorage!
    guard range.location + range.length <= storage.length else {
      volatileRange = nil
      return
    }

    suppressCallbacks {
      storage.beginEditing()
      storage.deleteCharacters(in: range)
      storage.endEditing()
    }

    volatileRange = nil
    onDisplayTextChanged?()
  }

  /// Finalize volatile text: remove styling, keep the text, clear volatileRange.
  func finalizeVolatileText() {
    guard let range = volatileRange else { return }
    let storage = textStorage!
    guard range.location + range.length <= storage.length else {
      volatileRange = nil
      return
    }

    suppressCallbacks {
      storage.beginEditing()
      // Re-apply typingAttributes to restore normal text appearance.
      // Simply removing foregroundColor can leave text with no explicit color,
      // which may render incorrectly in dark mode.
      storage.setAttributes(typingAttributes, range: range)
      storage.endEditing()
      layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
      layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
    }

    volatileRange = nil
    onDisplayTextChanged?()
  }

  /// Return the finalized text (excluding volatile text).
  var finalizedString: String {
    guard let range = volatileRange else { return string }
    let nsString = string as NSString
    guard range.location + range.length <= nsString.length else { return string }
    let mutable = NSMutableString(string: nsString)
    mutable.deleteCharacters(in: range)
    return mutable as String
  }

  private func applyVolatileStyling(_ range: NSRange) {
    // Underlines identify replacement candidates; voice previews use color and background.
    guard let layoutManager else { return }
    layoutManager.addTemporaryAttribute(
      .foregroundColor,
      value: NSColor.secondaryLabelColor,
      forCharacterRange: range
    )
    layoutManager.addTemporaryAttribute(
      .backgroundColor,
      value: NSColor.systemGray.withAlphaComponent(0.1),
      forCharacterRange: range
    )
  }

  private func removingDuplicateLeadingPunctuation(_ text: String, at insertionPoint: Int) -> String
  {
    guard let storage = textStorage,
      insertionPoint > 0,
      insertionPoint <= storage.length,
      !text.isEmpty
    else { return text }
    let previousCharacter = (storage.string as NSString).substring(
      with: NSRange(location: insertionPoint - 1, length: 1))
    let firstCharacter = String(text.prefix(1))
    guard previousCharacter == firstCharacter,
      Character(firstCharacter).isPunctuation
    else { return text }
    return String(text.dropFirst())
  }

  private func suppressCallbacks(_ operation: () -> Void) {
    let wasSuppressingCallbacks = isSuppressingCallbacks
    isSuppressingCallbacks = true
    operation()
    isSuppressingCallbacks = wasSuppressingCallbacks
  }

  // MARK: - Replacement previews

  func showReplacementPreviews(_ matches: [ReplacementMatch]) {
    previewMatches = matches
    onReplaceCandidate = nil
    needsDisplay = true
  }

  func showReplacementCandidates(
    _ matches: [ReplacementMatch], onReplace: @escaping (ReplacementMatch) -> Void
  ) {
    previewMatches = matches
    onReplaceCandidate = onReplace
    needsDisplay = true
  }

  func clearReplacementPreviews() {
    previewMatches = []
    onReplaceCandidate = nil
    needsDisplay = true
  }

  // MARK: - Underline drawing

  override func draw(_ dirtyRect: NSRect) {
    // Keep wantsUpdateLayer false: layer updates bypass this underline drawing path.
    super.draw(dirtyRect)
    drawReplacementUnderlines()
  }

  private func drawReplacementUnderlines() {
    guard !previewMatches.isEmpty,
      let layoutManager, let textContainer
    else { return }
    let origin = textContainerOrigin
    let nsString = string as NSString
    let underlineColor = NSColor.controlAccentColor

    for match in previewMatches {
      guard match.range.location >= 0,
        match.range.location + match.range.length <= nsString.length
      else { continue }

      let glyphRange = layoutManager.glyphRange(
        forCharacterRange: match.range,
        actualCharacterRange: nil
      )

      // Enumerate line fragments to draw underlines per visual line,
      // avoiding a single line spanning the full width across line breaks.
      layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
        _, _, _, effectiveRange, _ in
        let clippedRange = NSIntersectionRange(glyphRange, effectiveRange)
        guard clippedRange.length > 0 else { return }
        let lineRect = layoutManager.boundingRect(
          forGlyphRange: clippedRange,
          in: textContainer
        )
        let viewRect = lineRect.offsetBy(dx: origin.x, dy: origin.y)

        underlineColor.setStroke()
        let linePath = NSBezierPath()
        let lineY = viewRect.maxY - 1
        linePath.move(to: NSPoint(x: viewRect.minX, y: lineY))
        linePath.line(to: NSPoint(x: viewRect.maxX, y: lineY))
        linePath.lineWidth = 2
        linePath.stroke()
      }
    }
  }

  // MARK: - Text change callbacks

  override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool
  {
    // Finalize volatile text before keyboard input so it becomes confirmed text.
    if let range = volatileRange, !isSuppressingCallbacks {
      if let storage = textStorage, range.location + range.length <= storage.length {
        let volatileText = (storage.string as NSString).substring(with: range)
        finalizeVolatileText()
        onVolatileFinalized?(volatileText)
      } else {
        clearVolatileText()
      }
    }
    return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
  }

  override func didChangeText() {
    super.didChangeText()
    guard !isSuppressingCallbacks else { return }
    onTextChanged?(string)
  }

  override func insertText(_ string: Any, replacementRange: NSRange) {
    super.insertText(string, replacementRange: replacementRange)
    onTextCommitted?()
  }

  // MARK: - Cursor movement

  override func setSelectedRanges(
    _ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool
  ) {
    super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
    if !stillSelectingFlag, !isSuppressingCallbacks {
      onCursorMoved?(selectedRange().location)
    }
  }

  // MARK: - Context menu

  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = super.menu(for: event) ?? NSMenu()
    if isEditable, !hasMarkedText(), volatileRange == nil,
      let onReplaceCandidate, let match = replacementCandidate(at: convert(event.locationInWindow, from: nil))
    {
      menu.addItem(.separator())
      let item = NSMenuItem(
        title: String(localized: "Replace This Occurrence"),
        action: #selector(replaceOccurrenceFromMenu(_:)), keyEquivalent: "")
      item.target = self
      // Capture this menu's candidate and callback, rather than a subsequently
      // refreshed list. The service validates its document and rules snapshot.
      item.representedObject = ReplacementMenuAction { onReplaceCandidate(match) }
      menu.addItem(item)
    }
    if selectedRange().length > 0 {
      menu.addItem(.separator())
      let item = NSMenuItem(
        title: String(localized: "Add Replacement Rule\u{2026}"),
        action: #selector(addReplacementRuleFromMenu(_:)), keyEquivalent: "")
      item.target = self
      menu.addItem(item)
    }
    return menu
  }

  private func replacementCandidate(at point: NSPoint) -> ReplacementMatch? {
    guard let layoutManager, let textContainer else { return nil }
    let containerPoint = NSPoint(
      x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
    let glyph = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
    guard glyph < layoutManager.numberOfGlyphs,
      layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        .contains(containerPoint)
    else { return nil }
    let character = layoutManager.characterIndexForGlyph(at: glyph)
    return previewMatches.first { NSLocationInRange(character, $0.range) }
  }

  @objc private func replaceOccurrenceFromMenu(_ sender: NSMenuItem) {
    (sender.representedObject as? ReplacementMenuAction)?.perform()
  }

  private final class ReplacementMenuAction: NSObject {
    let perform: () -> Void
    init(perform: @escaping () -> Void) { self.perform = perform }
  }

  @objc private func addReplacementRuleFromMenu(_ sender: Any?) {
    let range = selectedRange()
    guard range.length > 0,
      range.location + range.length <= (string as NSString).length
    else { return }
    let selectedText = (string as NSString).substring(with: range)
    onAddReplacementRule?(selectedText)
  }
}
