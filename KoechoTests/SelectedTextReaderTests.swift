import Foundation
import Testing
@testable import Koecho

struct SelectedTextReaderTests {
    @Test func readReturnsNilInTestEnvironment() {
        let reader = SelectedTextReader()
        let result = reader.read(from: ProcessInfo.processInfo.processIdentifier)
        #expect(result == nil)
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
