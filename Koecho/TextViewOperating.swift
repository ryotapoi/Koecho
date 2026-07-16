import AppKit
import KoechoCore

@MainActor
protocol TextViewOperating: AnyObject {
  var string: String { get }
  var finalizedString: String { get }
  var volatileRange: NSRange? { get }
  func hasMarkedText() -> Bool
  func commitMarkedTextIfNeeded()
  func replaceText(_ text: String)
  func replaceText(_ text: String, selecting range: NSRange)
  func insertFinalizedText(_ text: String, at position: Int) -> String
  func setVolatileText(_ text: String, at position: Int)
  func clearVolatileText()
  func finalizeVolatileText()
  func showReplacementPreviews(_ matches: [ReplacementMatch])
  func clearReplacementPreviews()
  func makeFirstResponder(in panel: InputPanel)
  func setSelectedRange(_ range: NSRange)
  func selectedRange() -> NSRange
  func scrollRangeToVisible(_ range: NSRange)
}
