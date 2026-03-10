import AppKit
import KoechoPlatform
@testable import Koecho

@MainActor
final class MockSelectedTextReader: SelectedTextReading {
    var resultToReturn: SelectedTextResult?
    func read(from pid: pid_t) -> SelectedTextResult? { resultToReturn }
}
