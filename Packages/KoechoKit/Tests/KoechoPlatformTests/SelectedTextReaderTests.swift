@preconcurrency import ApplicationServices
import Foundation
import KoechoCore
import Testing
@testable import KoechoPlatform

private struct MockAccessibilityClient: AccessibilityClient {
    var trusted = true
    var element: AXUIElement? = AXUIElementCreateSystemWide()
    var text: String?

    func isProcessTrusted() -> Bool { trusted }
    func focusedUIElement(for pid: pid_t) -> AXUIElement? { element }
    func selectedText(of element: AXUIElement) -> String? { text }
}

@MainActor
struct SelectedTextReaderTests {
    @Test func readReturnsNilWhenNotTrusted() {
        let client = MockAccessibilityClient(trusted: false)
        let reader = SelectedTextReader(accessibilityClient: client)
        let result = reader.read(from: 1)
        #expect(result == nil)
    }

    @Test func readReturnsNilWhenNoFocusedElement() {
        let client = MockAccessibilityClient(element: nil)
        let reader = SelectedTextReader(accessibilityClient: client)
        let result = reader.read(from: 1)
        #expect(result == nil)
    }

    @Test func readReturnsNilWhenNoSelectedText() {
        let client = MockAccessibilityClient(text: nil)
        let reader = SelectedTextReader(accessibilityClient: client)
        let result = reader.read(from: 1)
        #expect(result == nil)
    }

    @Test func readReturnsText() {
        let client = MockAccessibilityClient(text: "hello")
        let reader = SelectedTextReader(accessibilityClient: client)
        let result = reader.read(from: 1)
        #expect(result == SelectedTextResult(text: "hello"))
    }

    @Test func selectedTextResultEquatable() {
        let a = SelectedTextResult(text: "hello")
        let b = SelectedTextResult(text: "hello")
        let c = SelectedTextResult(text: "world")
        #expect(a == b)
        #expect(a != c)
    }
}
