import Testing

@testable import KoechoPlatform

struct TaskTimeoutTests {
  @Test func completedTaskDoesNotTimeOut() async {
    let task = Task {}

    let timedOut = await TaskTimeout.hasTimedOut(task, seconds: 1)

    #expect(!timedOut)
  }

  @Test func unfinishedTaskTimesOut() async {
    let task = Task {
      _ = try? await Task.sleep(for: .seconds(5))
    }
    defer { task.cancel() }

    let timedOut = await TaskTimeout.hasTimedOut(task, seconds: 0.01)

    #expect(timedOut)
  }
}
