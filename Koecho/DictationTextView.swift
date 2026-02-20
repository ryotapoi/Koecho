import AppKit

final class DictationTextView: NSTextView {
    var onTextChanged: ((String) -> Void)?
    var onTextCommitted: (() -> Void)?
    var onAddReplacementRule: ((String) -> Void)?

    /// When true, `didChangeText()` will not fire `onTextChanged`.
    /// Used by both the NSViewRepresentable Coordinator (to prevent feedback
    /// loops during `updateNSView`) and the controller (when programmatically
    /// clearing the text view).
    var isSuppressingCallbacks = false

    /// Replacement preview data drawn as underlines in `draw(_:)`.
    /// Subviews must not be added during Dictation — doing so corrupts
    /// the marked text state and causes duplicate text.
    private var previewMatches: [ReplacementMatch] = []

    /// Tracking areas for hover detection over underlined matches.
    private var previewTrackingAreas: [NSTrackingArea] = []
    private var tooltipTextByArea: [ObjectIdentifier: String] = [:]

    /// Lightweight floating window for instant tooltip display.
    private var tipWindow: NSWindow?

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
                ? "\(original) → (delete)"
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

    override func didChangeText() {
        super.didChangeText()
        guard !isSuppressingCallbacks else { return }
        onTextChanged?(string)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        onTextCommitted?()
    }

    // MARK: - Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        guard selectedRange().length > 0 else { return menu }
        menu?.addItem(.separator())
        let item = NSMenuItem(
            title: "Add Replacement Rule\u{2026}",
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
