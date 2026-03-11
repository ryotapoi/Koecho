import ApplicationServices
import KoechoCore
import os

public nonisolated struct SelectedTextResult: Sendable, Equatable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

public protocol SelectedTextReading {
    func read(from pid: pid_t) -> SelectedTextResult?
}

public nonisolated final class SelectedTextReader: SelectedTextReading, Sendable {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "SelectedTextReader")
    private let accessibilityClient: any AccessibilityClient

    public init(accessibilityClient: any AccessibilityClient = LiveAccessibilityClient()) {
        self.accessibilityClient = accessibilityClient
    }

    public func read(from pid: pid_t) -> SelectedTextResult? {
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

        logger.info("Read selected text (\(text.count) chars) from pid \(pid)")
        return SelectedTextResult(text: text)
    }
}
