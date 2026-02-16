import ApplicationServices
import os

nonisolated struct SelectedTextResult: Sendable, Equatable {
    var text: String
    var start: String
    var end: String
}

nonisolated final class SelectedTextReader: Sendable {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "SelectedTextReader")

    func read(from pid: pid_t) -> SelectedTextResult? {
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility not trusted, cannot read selected text")
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)

        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedResult == .success, let focusedElement = focusedValue else {
            logger.debug("No focused element for pid \(pid)")
            return nil
        }

        // CFTypeRef from kAXFocusedUIElementAttribute is always AXUIElement,
        // but guard defensively in case of unexpected API behavior.
        guard CFGetTypeID(focusedElement as CFTypeRef) == AXUIElementGetTypeID() else {
            logger.debug("Focused element is not an AXUIElement for pid \(pid)")
            return nil
        }
        let element = focusedElement as! AXUIElement

        var selectedTextValue: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )
        guard textResult == .success, let text = selectedTextValue as? String, !text.isEmpty else {
            logger.debug("No selected text for pid \(pid)")
            return nil
        }

        var start = ""
        var end = ""

        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        if rangeResult == .success, let rangeRef = rangeValue,
           CFGetTypeID(rangeRef as CFTypeRef) == AXValueGetTypeID()
        {
            var range = CFRange(location: 0, length: 0)
            if AXValueGetValue(rangeRef as! AXValue, .cfRange, &range) {
                start = String(range.location)
                end = String(range.location + range.length)
            }
        }

        logger.info("Read selected text (\(text.count) chars) from pid \(pid)")
        return SelectedTextResult(text: text, start: start, end: end)
    }
}
