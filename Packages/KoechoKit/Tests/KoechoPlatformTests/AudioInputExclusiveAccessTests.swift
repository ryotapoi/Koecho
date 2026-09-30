import Testing

@testable import KoechoPlatform

@MainActor
struct AudioInputExclusiveAccessTests {
  @Test func acquireAndReleaseUpdateUsage() {
    let access = AudioInputExclusiveAccess()

    #expect(access.isInUse == false)
    access.acquire()
    #expect(access.isInUse == true)
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
    var called = false
    access.markAsActive { called = true }
    #expect(access.isInUse == true)

    access.clearActive()
    #expect(access.isInUse == false)
    access.acquire()
    #expect(!called)
  }

  @Test func separateInstancesDoNotShareExclusiveAccessState() {
    let first = AudioInputExclusiveAccess()
    let second = AudioInputExclusiveAccess()

    first.acquire()

    #expect(first.isInUse)
    #expect(!second.isInUse)
  }
}
