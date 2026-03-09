import ApplicationServices

protocol AccessibilityClient: Sendable {
    func isProcessTrusted() -> Bool
    func focusedUIElement(for pid: pid_t) -> AXUIElement?
    func selectedText(of element: AXUIElement) -> String?
    func selectedTextRange(of element: AXUIElement) -> CFRange?
}

nonisolated struct LiveAccessibilityClient: AccessibilityClient {
    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func focusedUIElement(for pid: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard result == .success, let focusedElement = focusedValue else {
            return nil
        }

        guard CFGetTypeID(focusedElement as CFTypeRef) == AXUIElementGetTypeID() else {
            return nil
        }
        return (focusedElement as! AXUIElement)
    }

    func selectedText(of element: AXUIElement) -> String? {
        var selectedTextValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )
        guard result == .success, let text = selectedTextValue as? String, !text.isEmpty else {
            return nil
        }
        return text
    }

    func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard result == .success, let rangeRef = rangeValue,
              CFGetTypeID(rangeRef as CFTypeRef) == AXValueGetTypeID()
        else {
            return nil
        }
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &range) else {
            return nil
        }
        return range
    }
}
