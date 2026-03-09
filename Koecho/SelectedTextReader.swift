import ApplicationServices
import os

nonisolated struct SelectedTextResult: Sendable, Equatable {
    var text: String
    var start: String
    var end: String
}

protocol SelectedTextReading {
    func read(from pid: pid_t) -> SelectedTextResult?
}

nonisolated final class SelectedTextReader: SelectedTextReading, Sendable {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "SelectedTextReader")
    private let accessibilityClient: any AccessibilityClient

    init(accessibilityClient: any AccessibilityClient = LiveAccessibilityClient()) {
        self.accessibilityClient = accessibilityClient
    }

    func read(from pid: pid_t) -> SelectedTextResult? {
        guard accessibilityClient.isProcessTrusted() else {
            logger.warning("Accessibility not trusted, cannot read selected text")
            return nil
        }

        guard let element = accessibilityClient.focusedUIElement(for: pid) else {
            logger.debug("No focused element for pid \(pid)")
            return nil
        }

        guard let text = accessibilityClient.selectedText(of: element) else {
            logger.debug("No selected text for pid \(pid)")
            return nil
        }

        var start = ""
        var end = ""

        if let range = accessibilityClient.selectedTextRange(of: element) {
            start = String(range.location)
            end = String(range.location + range.length)
        }

        logger.info("Read selected text (\(text.count) chars) from pid \(pid)")
        return SelectedTextResult(text: text, start: start, end: end)
    }
}
