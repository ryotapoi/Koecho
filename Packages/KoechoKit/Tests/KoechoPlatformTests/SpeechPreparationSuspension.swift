import Foundation

// A non-cooperative OS wait: cancellation does not resume it.
@MainActor
final class SpeechPreparationSuspension<Value: Sendable> {
  private var continuation: CheckedContinuation<Value, Never>?
  private var arrival: CheckedContinuation<Void, Never>?
  private var hasArrived = false

  func wait() async -> Value {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
      hasArrived = true
      arrival?.resume()
      arrival = nil
    }
  }

  func waitForArrival() async {
    guard !hasArrived else { return }
    await withCheckedContinuation { arrival = $0 }
  }

  func resume(returning value: Value) {
    continuation?.resume(returning: value)
    continuation = nil
  }
}
