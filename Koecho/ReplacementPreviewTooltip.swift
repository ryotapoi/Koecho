import AppKit

final class ReplacementPreviewTooltip {
  private(set) var window: NSWindow?

  func show(_ text: String, near localRect: NSRect, in hostView: NSView) {
    hide()
    guard let parentWindow = hostView.window else { return }

    let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let padding = NSSize(width: 12, height: 6)
    let windowSize = NSSize(
      width: ceil(textSize.width + padding.width),
      height: ceil(textSize.height + padding.height)
    )

    // Keep the tooltip above the preview so it does not overlap the Dictation microphone icon.
    let abovePoint = NSPoint(x: localRect.minX, y: localRect.minY - 4)
    let belowPoint = NSPoint(x: localRect.minX, y: localRect.maxY + 4)
    let aboveAnchor = screenPoint(abovePoint, in: hostView, window: parentWindow)
    let belowAnchor = screenPoint(belowPoint, in: hostView, window: parentWindow)
    let visibleFrame = (parentWindow.screen ?? NSScreen.main)?.visibleFrame
    let origin = Self.windowOrigin(
      windowSize: windowSize,
      aboveAnchor: aboveAnchor,
      belowAnchor: belowAnchor,
      visibleFrame: visibleFrame
    )

    let tooltipWindow = NSWindow(
      contentRect: NSRect(origin: origin, size: windowSize),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    tooltipWindow.level = .floating
    tooltipWindow.isOpaque = false
    tooltipWindow.backgroundColor = .clear
    tooltipWindow.hasShadow = true
    tooltipWindow.ignoresMouseEvents = true

    let contentView = ReplacementPreviewTooltipContentView(
      frame: NSRect(origin: .zero, size: windowSize)
    )
    contentView.text = text
    contentView.font = font
    tooltipWindow.contentView = contentView

    tooltipWindow.orderFront(nil)
    window = tooltipWindow
  }

  func hide() {
    window?.orderOut(nil)
    window = nil
  }

  static func windowOrigin(
    windowSize: NSSize,
    aboveAnchor: NSPoint,
    belowAnchor: NSPoint,
    visibleFrame: NSRect?
  ) -> NSPoint {
    guard let visibleFrame else { return aboveAnchor }

    var origin = aboveAnchor
    if origin.x + windowSize.width > visibleFrame.maxX {
      origin.x = visibleFrame.maxX - windowSize.width
    }
    if origin.x < visibleFrame.minX {
      origin.x = visibleFrame.minX
    }
    if origin.y + windowSize.height > visibleFrame.maxY {
      origin.y = belowAnchor.y - windowSize.height
    }
    return origin
  }

  private func screenPoint(_ point: NSPoint, in hostView: NSView, window: NSWindow) -> NSPoint {
    window.convertPoint(toScreen: hostView.convert(point, to: nil))
  }
}

final class ReplacementPreviewTooltipContentView: NSView {
  var text: String = ""
  var font: NSFont = .systemFont(ofSize: NSFont.smallSystemFontSize)

  override func draw(_ dirtyRect: NSRect) {
    let backgroundColor = NSColor.windowBackgroundColor
    let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
    backgroundColor.setFill()
    path.fill()

    NSColor.separatorColor.setStroke()
    path.lineWidth = 0.5
    path.stroke()

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
