import SwiftUI

/// Keeps the trailing 70 percent of the space after the shared label column for controls.
struct AudioVolumeSettingsLayout: Layout {
  private let spacing: CGFloat = 8
  private let controlFraction: CGFloat = 0.7

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let labelSize = subviews[0].sizeThatFits(.unspecified)
    let idealContentSize = subviews[1].sizeThatFits(.unspecified)
    let width = proposal.width ?? labelSize.width + spacing + idealContentSize.width / controlFraction
    let controlWidth = max(0, width - labelSize.width - spacing) * controlFraction
    let contentSize = subviews[1].sizeThatFits(ProposedViewSize(width: controlWidth, height: nil))
    return CGSize(width: width, height: max(labelSize.height, contentSize.height))
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let labelSize = subviews[0].sizeThatFits(.unspecified)
    let controlWidth = max(0, bounds.width - labelSize.width - spacing) * controlFraction
    subviews[0].place(
      at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
      proposal: ProposedViewSize(labelSize)
    )
    subviews[1].place(
      at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
      proposal: ProposedViewSize(width: controlWidth, height: nil)
    )
  }
}
