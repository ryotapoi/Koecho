import Foundation
import Synchronization

enum TaskTimeout {
  /// Race a task against a timeout. Returns `true` if the timeout fires first.
  static func hasTimedOut<Failure: Error>(
    _ task: Task<Void, Failure>,
    seconds: Double
  ) async -> Bool {
    await withCheckedContinuation { continuation in
      let race = TimeoutRace()
      let waiter = Task {
        _ = try? await task.value
        race.finish(continuation, returning: false)
      }
      race.setWaiter(waiter)

      let timer = Task {
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        race.finish(continuation, returning: true)
      }
      race.setTimer(timer)
    }
  }
}

private final class TimeoutRace: Sendable {
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
    _ continuation: CheckedContinuation<Bool, Never>,
    returning value: Bool
  ) {
    let result = state.withLock { state -> (shouldResume: Bool, task: Task<Void, Never>?) in
      guard !state.hasResumed else { return (false, nil) }
      state.hasResumed = true
      return (true, value ? state.waiter : state.timer)
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
