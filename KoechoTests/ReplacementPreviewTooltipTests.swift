import AppKit
import Testing

@testable import Koecho

@MainActor
@Suite(.serialized)
struct ReplacementPreviewTooltipTests {
  @Test func windowOriginKeepsUnclampedPosition() {
    let origin = ReplacementPreviewTooltip.windowOrigin(
      windowSize: NSSize(width: 80, height: 20),
      aboveAnchor: NSPoint(x: 100, y: 100),
      belowAnchor: NSPoint(x: 100, y: 140),
      visibleFrame: NSRect(x: 0, y: 0, width: 400, height: 300)
    )

    #expect(origin == NSPoint(x: 100, y: 100))
  }

  @Test func windowOriginClampsToRightEdge() {
    let origin = ReplacementPreviewTooltip.windowOrigin(
      windowSize: NSSize(width: 80, height: 20),
      aboveAnchor: NSPoint(x: 350, y: 100),
      belowAnchor: NSPoint(x: 350, y: 140),
      visibleFrame: NSRect(x: 0, y: 0, width: 400, height: 300)
    )

    #expect(origin == NSPoint(x: 320, y: 100))
  }

  @Test func windowOriginClampsToLeftEdge() {
    let origin = ReplacementPreviewTooltip.windowOrigin(
      windowSize: NSSize(width: 80, height: 20),
      aboveAnchor: NSPoint(x: 30, y: 100),
      belowAnchor: NSPoint(x: 30, y: 140),
      visibleFrame: NSRect(x: 50, y: 0, width: 400, height: 300)
    )

    #expect(origin == NSPoint(x: 50, y: 100))
  }

  @Test func windowOriginMovesBelowWhenAboveWouldCrossTopEdge() {
    let origin = ReplacementPreviewTooltip.windowOrigin(
      windowSize: NSSize(width: 80, height: 20),
      aboveAnchor: NSPoint(x: 100, y: 290),
      belowAnchor: NSPoint(x: 100, y: 250),
      visibleFrame: NSRect(x: 0, y: 0, width: 400, height: 300)
    )

    #expect(origin == NSPoint(x: 100, y: 230))
  }

  @Test func showAndHideOwnTooltipWindowLifecycle() {
    let parentWindow = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 300, height: 200),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
    parentWindow.contentView = hostView
    let tooltip = ReplacementPreviewTooltip()

    tooltip.show(
      "original → replacement",
      near: NSRect(x: 20, y: 20, width: 40, height: 16),
      in: hostView
    )

    let tooltipWindow = tooltip.window
    let contentView = tooltipWindow?.contentView as? ReplacementPreviewTooltipContentView
    #expect(tooltipWindow != nil)
    #expect(tooltipWindow?.styleMask == [.borderless])
    #expect(tooltipWindow?.level == .floating)
    #expect(tooltipWindow?.isOpaque == false)
    #expect(tooltipWindow?.backgroundColor == .clear)
    #expect(tooltipWindow?.hasShadow == true)
    #expect(tooltipWindow?.ignoresMouseEvents == true)
    #expect(contentView?.text == "original → replacement")

    tooltip.hide()

    #expect(tooltip.window == nil)
    #expect(tooltipWindow?.isVisible == false)
  }
}
