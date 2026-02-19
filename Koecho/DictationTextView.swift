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

    override func didChangeText() {
        super.didChangeText()
        guard !isSuppressingCallbacks else { return }
        onTextChanged?(string)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        onTextCommitted?()
    }

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
