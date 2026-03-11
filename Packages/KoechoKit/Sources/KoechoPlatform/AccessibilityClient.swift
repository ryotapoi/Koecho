import ApplicationServices
import KoechoCore

public protocol AccessibilityClient: Sendable {
    func isProcessTrusted() -> Bool
    func focusedUIElement(for pid: pid_t) -> AXUIElement?
    func selectedText(of element: AXUIElement) -> String?
}

public nonisolated struct LiveAccessibilityClient: AccessibilityClient {
    public init() {}

    public func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public func focusedUIElement(for pid: pid_t) -> AXUIElement? {
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

    public func selectedText(of element: AXUIElement) -> String? {
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

}
