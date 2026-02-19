import AppKit
import SwiftUI

struct DictationTextEditor: NSViewRepresentable {
    var text: String
    var isDisabled: Bool
    var onTextChanged: (String) -> Void
    var onTextCommitted: () -> Void
    var onAddReplacementRule: (String) -> Void
    var onViewCreated: (DictationTextView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = DictationTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 5, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.isEditable = !isDisabled

        textView.onTextChanged = onTextChanged
        textView.onTextCommitted = onTextCommitted
        textView.onAddReplacementRule = onAddReplacementRule

        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        onViewCreated(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        textView.onTextChanged = onTextChanged
        textView.onTextCommitted = onTextCommitted
        textView.onAddReplacementRule = onAddReplacementRule

        if textView.string != text,
           !textView.isSuppressingCallbacks,
           !textView.hasMarkedText() {
            textView.isSuppressingCallbacks = true
            textView.string = text
            textView.isSuppressingCallbacks = false
        }

        textView.isEditable = !isDisabled
    }

    final class Coordinator {
        var textView: DictationTextView?
    }
}
