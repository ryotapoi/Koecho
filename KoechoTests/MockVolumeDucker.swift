@testable import Koecho

@MainActor
final class MockVolumeDucker: VolumeDucking {
    var duckCallCount = 0
    var restoreCallCount = 0

    func duck() {
        duckCallCount += 1
    }

    func restore() {
        restoreCallCount += 1
    }
}
