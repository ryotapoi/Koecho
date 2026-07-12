@MainActor
public final class AudioInputExclusiveAccess {
  public static let shared = AudioInputExclusiveAccess()

  public static var isInUse: Bool {
    shared.isInUse
  }

  public static func acquire() {
    shared.acquire()
  }

  public static func release() {
    shared.release()
  }

  public private(set) var isInUse = false

  /// Called before acquiring — stops any active level monitoring.
  private var onAcquire: (() -> Void)?

  /// Acquire audio input. Stops any active level monitor first.
  public func acquire() {
    onAcquire?()
    isInUse = true
  }

  /// Release audio input.
  public func release() {
    isInUse = false
  }

  /// Register a handler that marks this caller as the active level monitor.
  /// The handler is called when another component acquires audio input.
  func markAsActive(onAcquire handler: @escaping () -> Void) {
    onAcquire = handler
    isInUse = true
  }

  /// Clear the active level monitor state.
  func clearActive() {
    onAcquire = nil
    isInUse = false
  }
}
