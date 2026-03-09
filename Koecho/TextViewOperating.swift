import AppKit

@MainActor
protocol TextViewOperating: AnyObject {
    var string: String { get }
    var finalizedString: String { get }
    var volatileRange: NSRange? { get }
    var textStorage: NSTextStorage? { get }
    var typingAttributes: [NSAttributedString.Key: Any] { get }
    func hasMarkedText() -> Bool
    var isSuppressingCallbacks: Bool { get set }
    func setString(_ text: String, suppressingCallbacks: Bool)
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
