import Testing
@testable import KoechoPlatform

@MainActor
struct AudioInputExclusiveAccessTests {
    @Test func initialStateIsNotInUse() {
        defer { AudioInputExclusiveAccess.clearActive() }
        #expect(AudioInputExclusiveAccess.isInUse == false)
    }

    @Test func acquireSetsInUse() {
        defer { AudioInputExclusiveAccess.release() }
        AudioInputExclusiveAccess.acquire()
        #expect(AudioInputExclusiveAccess.isInUse == true)
    }

    @Test func releaseClearsInUse() {
        defer { AudioInputExclusiveAccess.clearActive() }
        AudioInputExclusiveAccess.acquire()
        AudioInputExclusiveAccess.release()
        #expect(AudioInputExclusiveAccess.isInUse == false)
    }

    @Test func acquireCallsOnAcquireHandler() {
        defer { AudioInputExclusiveAccess.clearActive() }
        var called = false
        AudioInputExclusiveAccess.markAsActive {
            called = true
        }
        #expect(AudioInputExclusiveAccess.isInUse == true)

        AudioInputExclusiveAccess.acquire()
        #expect(called == true)
    }

    @Test func clearActiveResetsState() {
        defer { AudioInputExclusiveAccess.clearActive() }
        AudioInputExclusiveAccess.markAsActive {}
        #expect(AudioInputExclusiveAccess.isInUse == true)

        AudioInputExclusiveAccess.clearActive()
        #expect(AudioInputExclusiveAccess.isInUse == false)
    }

    @Test func acquireStopsActiveLevelMonitor() {
        defer { AudioInputExclusiveAccess.clearActive() }
        let monitor = AudioInputLevelMonitor()
        AudioInputExclusiveAccess.markAsActive { [weak monitor] in
            monitor?.stop()
        }
        #expect(AudioInputExclusiveAccess.isInUse == true)

        // When another component acquires, the monitor should be stopped
        AudioInputExclusiveAccess.acquire()
        #expect(monitor.inputLevel == 0)
        #expect(AudioInputExclusiveAccess.isInUse == true)
    }
}
