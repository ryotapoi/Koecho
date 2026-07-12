import Testing

@testable import KoechoPlatform

@MainActor
struct AudioInputExclusiveAccessTests {
  @Test func initialStateIsNotInUse() {
    let access = AudioInputExclusiveAccess()

    #expect(access.isInUse == false)
  }

  @Test func acquireSetsInUse() {
    let access = AudioInputExclusiveAccess()

    access.acquire()

    #expect(access.isInUse == true)
  }

  @Test func releaseClearsInUse() {
    let access = AudioInputExclusiveAccess()
    access.acquire()

    access.release()

    #expect(access.isInUse == false)
  }

  @Test func acquireCallsOnAcquireHandler() {
    let access = AudioInputExclusiveAccess()
    var called = false
    access.markAsActive {
      called = true
    }
    #expect(access.isInUse == true)

    access.acquire()
    #expect(called == true)
  }

  @Test func clearActiveResetsState() {
    let access = AudioInputExclusiveAccess()
    access.markAsActive {}
    #expect(access.isInUse == true)

    access.clearActive()
    #expect(access.isInUse == false)
  }

  @Test func acquireStopsActiveLevelMonitor() {
    let access = AudioInputExclusiveAccess()
    let monitor = AudioInputLevelMonitor(exclusiveAccess: access)
    access.markAsActive { [weak monitor] in
      monitor?.stop()
    }
    #expect(access.isInUse == true)

    // When another component acquires, the monitor should be stopped
    access.acquire()
    #expect(monitor.inputLevel == 0)
    #expect(access.isInUse == true)
  }

  @Test func separateInstancesDoNotShareExclusiveAccessState() {
    let first = AudioInputExclusiveAccess()
    let second = AudioInputExclusiveAccess()

    first.acquire()

    #expect(first.isInUse)
    #expect(!second.isInUse)
  }
}
