import Foundation
import Synchronization

enum TaskTimeout {
  enum Outcome<Failure: Error>: Sendable {
    case completed(Result<Void, Failure>)
    case timedOut
  }

  /// Race a task against a timeout, preserving the winning completion result.
  static func wait<Failure: Error>(
    _ task: Task<Void, Failure>,
    seconds: Double
  ) async -> Outcome<Failure> {
    await withCheckedContinuation { continuation in
      let race = TimeoutRace<Failure>()
      let waiter = Task {
        let result = await task.result
        race.finish(continuation, returning: .completed(result))
      }
      race.setWaiter(waiter)

      let timer = Task {
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        race.finish(continuation, returning: .timedOut)
      }
      race.setTimer(timer)
    }
  }
}

private final class TimeoutRace<Failure: Error>: Sendable {
  private struct State {
    var hasResumed = false
    var waiter: Task<Void, Never>?
    var timer: Task<Void, Never>?
  }

  private let state = Mutex(State())

  func setWaiter(_ task: Task<Void, Never>) {
    set(task: task, to: \.waiter)
  }

  func setTimer(_ task: Task<Void, Never>) {
    set(task: task, to: \.timer)
  }

  func finish(
    _ continuation: CheckedContinuation<TaskTimeout.Outcome<Failure>, Never>,
    returning value: TaskTimeout.Outcome<Failure>
  ) {
    let result = state.withLock { state -> (shouldResume: Bool, task: Task<Void, Never>?) in
      guard !state.hasResumed else { return (false, nil) }
      state.hasResumed = true
      switch value {
      case .timedOut: return (true, state.waiter)
      case .completed: return (true, state.timer)
      }
    }
    guard result.shouldResume else { return }
    result.task?.cancel()
    continuation.resume(returning: value)
  }

  private func set(
    task: Task<Void, Never>,
    to keyPath: WritableKeyPath<State, Task<Void, Never>?>
  ) {
    let shouldCancel = state.withLock { state in
      guard !state.hasResumed else { return true }
      state[keyPath: keyPath] = task
      return false
    }
    if shouldCancel { task.cancel() }
  }
}
