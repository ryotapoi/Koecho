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

    /// When true, `didChangeText()` will not fire `onTextChanged`.
    /// Used by both the NSViewRepresentable Coordinator (to prevent feedback
    /// loops during `updateNSView`) and the controller (when programmatically
    /// clearing the text view).
    var isSuppressingCallbacks = false

    /// SpeechAnalyzer mode: range of volatile (unconfirmed) text in the text storage.
    private(set) var volatileRange: NSRange?

    /// Replacement preview data drawn as underlines in `draw(_:)`.
    /// Subviews must not be added during Dictation — doing so corrupts
    /// the marked text state and causes duplicate text.
    private var previewMatches: [ReplacementMatch] = []

    /// Tracking areas for hover detection over underlined matches.
    private var previewTrackingAreas: [NSTrackingArea] = []
    private var tooltipTextByArea: [ObjectIdentifier: String] = [:]

    /// Lightweight floating window for instant tooltip display.
    private var tipWindow: NSWindow?

    // MARK: - TextViewOperating

    func setString(_ text: String, suppressingCallbacks: Bool) {
        if suppressingCallbacks { isSuppressingCallbacks = true }
        string = text
        if suppressingCallbacks { isSuppressingCallbacks = false }
    }

    func makeFirstResponder(in panel: InputPanel) {
        panel.makeFirstResponder(self)
    }

    // MARK: - Volatile text

    /// Set volatile text at the given insertion point (UTF-16 offset).
    /// Replaces any previous volatile text.
    func setVolatileText(_ text: String, at insertionPoint: Int) {
        clearVolatileText()
        guard !text.isEmpty else { return }
        let nsText = text as NSString
        let storage = textStorage!
        let clampedPoint = min(insertionPoint, storage.length)

        isSuppressingCallbacks = true
        storage.beginEditing()
        storage.insert(NSAttributedString(string: text, attributes: typingAttributes), at: clampedPoint)
        storage.endEditing()
        isSuppressingCallbacks = false

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

        isSuppressingCallbacks = true
        storage.beginEditing()
        storage.deleteCharacters(in: range)
        storage.endEditing()
        isSuppressingCallbacks = false

        volatileRange = nil
    }

    /// Finalize volatile text: remove styling, keep the text, clear volatileRange.
    func finalizeVolatileText() {
        guard let range = volatileRange else { return }
        let storage = textStorage!
        guard range.location + range.length <= storage.length else {
            volatileRange = nil
            return
        }

        isSuppressingCallbacks = true
        storage.beginEditing()
        // Re-apply typingAttributes to restore normal text appearance.
        // Simply removing foregroundColor can leave text with no explicit color,
        // which may render incorrectly in dark mode.
        storage.setAttributes(typingAttributes, range: range)
        storage.endEditing()
        layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        isSuppressingCallbacks = false

        volatileRange = nil
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

    // MARK: - Replacement previews

    func showReplacementPreviews(_ matches: [ReplacementMatch]) {
        previewMatches = matches
        rebuildPreviewTrackingAreas()
        needsDisplay = true
    }

    func clearReplacementPreviews() {
        guard !previewMatches.isEmpty else { return }
        previewMatches = []
        removePreviewTrackingAreas()
        hideTip()
        needsDisplay = true
    }

    // MARK: - Tracking areas for hover

    private func removePreviewTrackingAreas() {
        for area in previewTrackingAreas {
            removeTrackingArea(area)
        }
        previewTrackingAreas.removeAll()
        tooltipTextByArea.removeAll()
    }

    private func rebuildPreviewTrackingAreas() {
        removePreviewTrackingAreas()
        guard let layoutManager, let textContainer else { return }
        let origin = textContainerOrigin
        let nsString = string as NSString

        for match in previewMatches {
            guard match.range.location >= 0,
                  match.range.location + match.range.length <= nsString.length else { continue }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: match.range,
                actualCharacterRange: nil
            )
            let rect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textContainer
            )
            let viewRect = rect.offsetBy(dx: origin.x, dy: origin.y)

            let original = nsString.substring(with: match.range)
            let tipText = match.replacement.isEmpty
                ? "\(original) → \(String(localized: "(delete)"))"
                : "\(original) → \(match.replacement)"

            let area = NSTrackingArea(
                rect: viewRect,
                options: [.mouseEnteredAndExited, .activeInActiveApp],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            previewTrackingAreas.append(area)
            tooltipTextByArea[ObjectIdentifier(area)] = tipText
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard let area = event.trackingArea,
              let text = tooltipTextByArea[ObjectIdentifier(area)] else {
            super.mouseEntered(with: event)
            return
        }
        showTip(text, near: area.rect)
    }

    override func mouseExited(with event: NSEvent) {
        guard let area = event.trackingArea,
              tooltipTextByArea[ObjectIdentifier(area)] != nil else {
            super.mouseExited(with: event)
            return
        }
        hideTip()
    }

    // MARK: - Instant tip window

    private func showTip(_ text: String, near localRect: NSRect) {
        hideTip()
        guard let parentWindow = window else { return }

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding = NSSize(width: 12, height: 6)
        let windowSize = NSSize(
            width: ceil(textSize.width + padding.width),
            height: ceil(textSize.height + padding.height)
        )

        // Position above the underlined text to avoid overlapping
        // the Dictation microphone icon that appears below the cursor.
        let localPoint = NSPoint(x: localRect.minX, y: localRect.minY - 4)
        let screenPoint = parentWindow.convertPoint(toScreen: convert(localPoint, to: nil))

        var origin = NSPoint(x: screenPoint.x, y: screenPoint.y)
        if let screen = parentWindow.screen ?? NSScreen.main {
            let frame = screen.visibleFrame
            if origin.x + windowSize.width > frame.maxX {
                origin.x = frame.maxX - windowSize.width
            }
            if origin.x < frame.minX {
                origin.x = frame.minX
            }
            if origin.y + windowSize.height > frame.maxY {
                // No room above — show below the text instead
                let belowPoint = NSPoint(x: localRect.minX, y: localRect.maxY + 4)
                let belowScreen = parentWindow.convertPoint(toScreen: convert(belowPoint, to: nil))
                origin.y = belowScreen.y - windowSize.height
            }
        }

        let tipWin = NSWindow(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        tipWin.level = .floating
        tipWin.isOpaque = false
        tipWin.backgroundColor = .clear
        tipWin.hasShadow = true
        tipWin.ignoresMouseEvents = true

        let contentView = TipContentView(frame: NSRect(origin: .zero, size: windowSize))
        contentView.text = text
        contentView.font = font
        tipWin.contentView = contentView

        tipWin.orderFront(nil)
        tipWindow = tipWin
    }

    private func hideTip() {
        tipWindow?.orderOut(nil)
        tipWindow = nil
    }

    // MARK: - Underline drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawReplacementUnderlines()
    }

    private func drawReplacementUnderlines() {
        guard !previewMatches.isEmpty,
              let layoutManager, let textContainer else { return }
        let origin = textContainerOrigin
        let nsString = string as NSString
        let underlineColor = NSColor.controlAccentColor

        for match in previewMatches {
            guard match.range.location >= 0,
                  match.range.location + match.range.length <= nsString.length else { continue }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: match.range,
                actualCharacterRange: nil
            )

            // Enumerate line fragments to draw underlines per visual line,
            // avoiding a single line spanning the full width across line breaks.
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, effectiveRange, _ in
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

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
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

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if !stillSelectingFlag, !isSuppressingCallbacks {
            onCursorMoved?(charRange.location)
        }
    }

    // MARK: - Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        guard selectedRange().length > 0 else { return menu }
        menu?.addItem(.separator())
        let item = NSMenuItem(
            title: String(localized: "Add Replacement Rule\u{2026}"),
            action: #selector(addReplacementRuleFromMenu(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu?.addItem(item)
        return menu
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

// MARK: - Tip content view

private final class TipContentView: NSView {
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: NSFont.smallSystemFontSize)

    override func draw(_ dirtyRect: NSRect) {
        // Rounded background
        let bgColor = NSColor.windowBackgroundColor
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        bgColor.setFill()
        path.fill()

        // Border
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}
