import Testing

@testable import KoechoPlatform

@MainActor
struct AudioInputExclusiveAccessTests {
  @Test func acquireAndReleaseUpdateUsage() {
    let access = AudioInputExclusiveAccess()

    #expect(access.isInUse == false)
    let id = access.acquire()
    #expect(access.isInUse == true)
    access.release(id)
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
    var called = false
    let id = access.markAsActive { called = true }
    #expect(access.isInUse == true)

    access.clearActive(id)
    #expect(access.isInUse == false)
    access.acquire()
    #expect(!called)
  }

  @Test func staleMonitorCleanupDoesNotReleaseRecognitionOrNewMonitor() {
    let access = AudioInputExclusiveAccess()
    let oldID = access.markAsActive {}
    let recognitionID = access.acquire()
    access.clearActive(oldID)
    #expect(access.isInUse)
    access.release(recognitionID)
    let newID = access.markAsActive {}
    access.clearActive(oldID)
    #expect(access.isInUse)
    access.clearActive(newID)
    #expect(!access.isInUse)
  }

  @Test func separateInstancesDoNotShareExclusiveAccessState() {
    let first = AudioInputExclusiveAccess()
    let second = AudioInputExclusiveAccess()

    first.acquire()

    #expect(first.isInUse)
    #expect(!second.isInUse)
  }
}
