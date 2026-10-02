import Testing

@testable import KoechoPlatform

struct TaskTimeoutTests {
  @Test func completedTaskSucceeds() async {
    let task = Task {}

    let outcome = await TaskTimeout.wait(task, seconds: 1)
    guard case .completed(.success) = outcome else {
      Issue.record("Expected successful completion")
      return
    }
  }

  @Test func cancelledTaskPreservesCancellation() async {
    let task = Task<Void, Error> { throw CancellationError() }

    let outcome = await TaskTimeout.wait(task, seconds: 1)
    guard case .completed(.failure(let error)) = outcome else {
      Issue.record("Expected cancellation failure")
      return
    }
    #expect(error is CancellationError)
  }

  @Test func failedTaskPreservesError() async {
    struct Failure: Error, Equatable { let code: Int }
    let task = Task<Void, Error> { throw Failure(code: 42) }

    let outcome = await TaskTimeout.wait(task, seconds: 1)
    guard case .completed(.failure(let error)) = outcome else {
      Issue.record("Expected task failure")
      return
    }
    #expect(error as? Failure == Failure(code: 42))
  }

  @Test func unfinishedTaskTimesOutBeforeLateCompletion() async {
    let (stream, continuation) = AsyncStream<Void>.makeStream()
    let task = Task {
      for await _ in stream {}
    }

    let outcome = await TaskTimeout.wait(task, seconds: 0.01)
    guard case .timedOut = outcome else {
      continuation.finish()
      Issue.record("Expected timeout while task is unfinished")
      return
    }
    #expect(!task.isCancelled)

    continuation.finish()
    await task.value
  }
}
