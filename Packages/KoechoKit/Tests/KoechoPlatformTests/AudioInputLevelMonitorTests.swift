import Testing
@testable import KoechoPlatform

@MainActor
struct AudioInputLevelMonitorTests {
    @Test func initDoesNotCrash() {
        let monitor = AudioInputLevelMonitor()
        _ = monitor.inputLevel
    }

    @Test func stopWithoutStartDoesNotCrash() {
        let monitor = AudioInputLevelMonitor()
        monitor.stop()
    }

    @Test func initialInputLevelIsZero() {
        let monitor = AudioInputLevelMonitor()
        #expect(monitor.inputLevel == 0)
    }
}
