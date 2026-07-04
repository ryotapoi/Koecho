import Foundation

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

private final class TimeoutRace: @unchecked Sendable {
  private let lock = NSLock()
  private var hasResumed = false
  private var waiter: Task<Void, Never>?
  private var timer: Task<Void, Never>?

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
    let taskToCancel: Task<Void, Never>?
    lock.lock()
    guard !hasResumed else {
      lock.unlock()
      return
    }
    hasResumed = true
    taskToCancel = value ? waiter : timer
    lock.unlock()

    taskToCancel?.cancel()
    continuation.resume(returning: value)
  }

  private func set(
    task: Task<Void, Never>,
    to keyPath: ReferenceWritableKeyPath<TimeoutRace, Task<Void, Never>?>
  ) {
    lock.lock()
    if hasResumed {
      lock.unlock()
      task.cancel()
      return
    }
    self[keyPath: keyPath] = task
    lock.unlock()
  }
}
