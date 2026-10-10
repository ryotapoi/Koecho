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
  private var previewRules: [ReplacementRule] = []
  let caretReplacementPreview = CaretReplacementPreview()
  private var windowObservers: [NSObjectProtocol] = []

  var onDisplayTextChanged: (() -> Void)?
  private var onReplaceCandidate: (([ReplacementMatch]) -> Void)?

  isolated deinit {
    for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
  }

  // MARK: - TextViewOperating

  /// Commits an active IME composition before an operation that may discard it.
  func commitMarkedTextIfNeeded() {
    guard hasMarkedText() else { return }
    unmarkText()
    inputContext?.discardMarkedText()
  }

  func replaceText(_ text: String) {
    clearReplacementPreviews()
    suppressCallbacks {
      clearVolatileText()
      string = text
    }
    onDisplayTextChanged?()
  }

  /// Replace the document and its selected result as one suppressed UI update.
  func replaceText(_ text: String, selecting range: NSRange) {
    clearReplacementPreviews()
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
    clearReplacementPreviews()
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
    caretReplacementPreview.cancel()
    previewMatches = matches
    onReplaceCandidate = nil
    needsDisplay = true
  }

  func showReplacementCandidates(
    _ matches: [ReplacementMatch], rules: [ReplacementRule] = [],
    onReplace: @escaping ([ReplacementMatch]) -> Void
  ) {
    if previewMatches != matches || previewRules != rules || onReplaceCandidate == nil {
      caretReplacementPreview.cancel()
    }
    previewRules = rules
    previewMatches = matches
    onReplaceCandidate = onReplace
    refreshCaretReplacementPreview()
    needsDisplay = true
  }

  func clearReplacementPreviews() {
    caretReplacementPreview.cancel()
    previewMatches = []
    onReplaceCandidate = nil
    needsDisplay = true
  }

  // MARK: - Caret replacement preview

  private func caretPreviewSnapshot() -> CaretReplacementPreview.Snapshot? {
    guard isEditable, !isHiddenOrHasHiddenAncestor,
      let window, window.isVisible, window.isKeyWindow, window.firstResponder === self,
      !hasMarkedText(), volatileRange == nil, onReplaceCandidate != nil,
      selectedRanges.count == 1, selectedRange().length == 0,
      let match = replacementTargets(previewMatches, selection: selectedRange()).first,
      match.range.location >= 0, NSMaxRange(match.range) <= (string as NSString).length
    else { return nil }
    return .init(text: string, caret: selectedRange().location, match: match)
  }

  private func refreshCaretReplacementPreview() {
    caretReplacementPreview.update(
      caretPreviewSnapshot(), current: { [weak self] in self?.caretPreviewSnapshot() },
      onChange: { [weak self] in self?.needsDisplay = true })
  }

  override func becomeFirstResponder() -> Bool {
    let result = super.becomeFirstResponder()
    if result {
      // NSWindow installs its first responder after this callback returns.
      DispatchQueue.main.async { [weak self] in self?.refreshCaretReplacementPreview() }
    }
    return result
  }

  override func resignFirstResponder() -> Bool {
    let result = super.resignFirstResponder()
    if result { caretReplacementPreview.cancel() }
    return result
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    caretReplacementPreview.cancel()
    for observer in windowObservers { NotificationCenter.default.removeObserver(observer) }
    windowObservers.removeAll()
    super.viewWillMove(toWindow: newWindow)
    guard let newWindow else { return }
    for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
      windowObservers.append(NotificationCenter.default.addObserver(
        forName: name, object: newWindow, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.caretReplacementPreview.cancel() }
      })
    }
    windowObservers.append(NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification, object: newWindow, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshCaretReplacementPreview() }
    })
  }

  override var isHidden: Bool {
    didSet {
      if isHidden { caretReplacementPreview.cancel() }
      else { refreshCaretReplacementPreview() }
    }
  }

  override var isEditable: Bool {
    didSet {
      if !isEditable { caretReplacementPreview.cancel() }
    }
  }

  override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
    caretReplacementPreview.cancel()
    super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
  }

  override func unmarkText() {
    caretReplacementPreview.cancel()
    super.unmarkText()
    onDisplayTextChanged?()
    refreshCaretReplacementPreview()
  }

  private func drawCaretReplacementPreview() {
    guard let snapshot = caretReplacementPreview.displayed,
      snapshot == caretPreviewSnapshot() else { return }
    var actualRange = NSRange()
    let screenRect = firstRect(forCharacterRange: NSRange(location: snapshot.caret, length: 0),
                               actualRange: &actualRange)
    guard let window else { return }
    let caretRect = convert(window.convertFromScreen(screenRect), from: nil)
    // An insertion rectangle can have zero width; give visibility testing a pixel of area.
    guard visibleRect.intersects(caretRect.insetBy(dx: -1, dy: 0)) else { return }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    let label = NSAttributedString(string: snapshot.label, attributes: [
      .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
      .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    let width = max(1, min(320, visibleRect.width - 16))
    let measured = label.boundingRect(with: NSSize(width: max(1, width - 16), height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading])
    let size = NSSize(width: min(width, ceil(measured.width) + 16),
                      height: min(visibleRect.height - 8, ceil(measured.height) + 12))
    let x = max(visibleRect.minX + 4, min(caretRect.minX, visibleRect.maxX - size.width - 4))
    var y = caretRect.maxY + 4
    if y + size.height > visibleRect.maxY - 4 { y = caretRect.minY - size.height - 4 }
    y = max(visibleRect.minY + 4, y)
    let rect = NSRect(origin: NSPoint(x: x, y: y), size: size)
    NSColor.controlBackgroundColor.setFill()
    let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
    path.fill()
    NSColor.separatorColor.setStroke()
    path.stroke()
    label.draw(with: rect.insetBy(dx: 8, dy: 6), options: [.usesLineFragmentOrigin, .usesFontLeading])
  }

  // MARK: - Underline drawing

  override func draw(_ dirtyRect: NSRect) {
    // Keep wantsUpdateLayer false: layer updates bypass this underline drawing path.
    super.draw(dirtyRect)
    drawReplacementUnderlines()
    drawCaretReplacementPreview()
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
    caretReplacementPreview.cancel()
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
    clearReplacementPreviews()
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
    caretReplacementPreview.cancel()
    super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
    if !stillSelectingFlag, !isSuppressingCallbacks {
      onCursorMoved?(selectedRange().location)
    }
    if !stillSelectingFlag { refreshCaretReplacementPreview() }
  }

  // MARK: - Context menu

  override func menu(for event: NSEvent) -> NSMenu? {
    // AppKit may select the clicked word while building its standard menu.
    // Interpret the user's existing selection before that side effect.
    let selection = selectedRange()
    let menu = super.menu(for: event) ?? NSMenu()
    var appItems: [NSMenuItem] = []
    if isEditable, !hasMarkedText(), volatileRange == nil,
      let onReplaceCandidate, let character = replacementCharacter(at: convert(event.locationInWindow, from: nil))
    {
      let usesSelection = selection.length > 0 && NSLocationInRange(character, selection)
      let targets = usesSelection
        ? replacementTargets(previewMatches, selection: selection)
        : previewMatches.filter { NSLocationInRange(character, $0.range) }.prefix(1).map { $0 }
      if !targets.isEmpty {
        let item = NSMenuItem(
          title: usesSelection ? String(localized: "Replace Selection") : String(localized: "Replace This Occurrence"),
          action: #selector(replaceOccurrenceFromMenu(_:)), keyEquivalent: "")
        item.target = self
        // Capture this menu's candidate and callback, rather than a subsequently
        // refreshed list. The service validates its document and rules snapshot.
        item.representedObject = ReplacementMenuAction { onReplaceCandidate(targets) }
        appItems.append(item)
      }
    }
    if selectedRange().length > 0 {
      let item = NSMenuItem(
        title: String(localized: "Add Replacement Rule\u{2026}"),
        action: #selector(addReplacementRuleFromMenu(_:)), keyEquivalent: "")
      item.target = self
      appItems.append(item)
    }
    if !appItems.isEmpty {
      if let firstItem = menu.items.first, !firstItem.isSeparatorItem {
        menu.insertItem(.separator(), at: 0)
      }
      for (index, item) in appItems.enumerated() {
        menu.insertItem(item, at: index)
      }
    }
    return menu
  }

  private func replacementCharacter(at point: NSPoint) -> Int? {
    guard let layoutManager, let textContainer else { return nil }
    let containerPoint = NSPoint(
      x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
    let glyph = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
    guard glyph < layoutManager.numberOfGlyphs,
      layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        .contains(containerPoint)
    else { return nil }
    let character = layoutManager.characterIndexForGlyph(at: glyph)
    return character
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

/// Owns the stop interval and its snapshot; cancellation also invalidates callbacks already queued.
@MainActor
final class CaretReplacementPreview {
  struct Snapshot: Equatable {
    let text: String
    let caret: Int
    let match: ReplacementMatch

    var label: String {
      let original = (text as NSString).substring(with: match.range)
      return "\(original) → \(match.replacement.isEmpty ? "∅" : match.replacement)"
    }
  }

  private(set) var timer: Timer?
  private(set) var displayed: Snapshot?
  private var pending: Snapshot?
  private var generation = 0
  private var onChange: (() -> Void)?

  func cancel() {
    generation += 1
    timer?.invalidate()
    timer = nil
    pending = nil
    displayed = nil
    onChange?()
  }

  func update(_ snapshot: Snapshot?, current: @escaping @MainActor () -> Snapshot?, onChange: @escaping () -> Void) {
    if let snapshot, snapshot == pending || snapshot == displayed { return }
    if snapshot == nil, pending == nil, displayed == nil { return }
    cancel()
    self.onChange = onChange
    guard let snapshot else { return }
    pending = snapshot
    let reservation = generation
    let timer = Timer(timeInterval: 0.7, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.generation == reservation else { return }
        self.timer = nil
        self.pending = nil
        guard current() == snapshot else { return }
        self.displayed = snapshot
        self.onChange?()
      }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }
}
