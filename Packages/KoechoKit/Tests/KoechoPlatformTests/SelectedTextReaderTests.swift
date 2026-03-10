@preconcurrency import ApplicationServices
import Foundation
import KoechoCore
import Testing
@testable import KoechoPlatform

private struct MockAccessibilityClient: AccessibilityClient {
    var trusted = true
    var element: AXUIElement? = AXUIElementCreateSystemWide()
    var text: String?
    var range: CFRange?

    func isProcessTrusted() -> Bool { trusted }
    func focusedUIElement(for pid: pid_t) -> AXUIElement? { element }
    func selectedText(of element: AXUIElement) -> String? { text }
    func selectedTextRange(of element: AXUIElement) -> CFRange? { range }
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

    @Test func readReturnsTextWithRange() {
        let client = MockAccessibilityClient(text: "hello", range: CFRange(location: 5, length: 5))
        let reader = SelectedTextReader(accessibilityClient: client)
        let result = reader.read(from: 1)
        #expect(result == SelectedTextResult(text: "hello", start: "5", end: "10"))
    }

    @Test func readReturnsTextWithoutRange() {
        let client = MockAccessibilityClient(text: "hello", range: nil)
        let reader = SelectedTextReader(accessibilityClient: client)
        let result = reader.read(from: 1)
        #expect(result == SelectedTextResult(text: "hello", start: "", end: ""))
    }

    @Test func selectedTextResultEquatable() {
        let a = SelectedTextResult(text: "hello", start: "0", end: "5")
        let b = SelectedTextResult(text: "hello", start: "0", end: "5")
        let c = SelectedTextResult(text: "world", start: "0", end: "5")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func selectedTextResultWithEmptyRange() {
        let result = SelectedTextResult(text: "hello", start: "", end: "")
        #expect(result.text == "hello")
        #expect(result.start == "")
        #expect(result.end == "")
    }
}
