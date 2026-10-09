import Foundation

@MainActor
public final class AudioInputExclusiveAccess {
  public static let shared = AudioInputExclusiveAccess()

  public var isInUse: Bool { isAcquired || activeMonitorID != nil }
  private var isAcquired = false
  private var activeMonitorID: UUID?
  private var onAcquire: (() -> Void)?
  private var releaseHandler: (id: UUID, handler: () -> Void)?

  /// Acquire audio input. Stops any active level monitor first.
  public func acquire() {
    isAcquired = true
    onAcquire?()
  }

  /// Release recognition input after its capture has stopped.
  public func release() {
    guard isAcquired else { return }
    isAcquired = false
    releaseHandler?.handler()
  }

  func resumeMonitoringOnRelease(_ handler: @escaping () -> Void) -> UUID {
    let id = UUID()
    releaseHandler = (id, handler)
    return id
  }

  func cancelMonitoringResume(_ id: UUID) {
    guard releaseHandler?.id == id else { return }
    releaseHandler = nil
  }

  /// Register the active capture separately from the pending monitoring request.
  @discardableResult
  func markAsActive(onAcquire handler: @escaping () -> Void) -> UUID {
    let id = UUID()
    activeMonitorID = id
    onAcquire = handler
    return id
  }

  func clearActive(_ id: UUID) {
    guard activeMonitorID == id else { return }
    activeMonitorID = nil
    onAcquire = nil
  }
}
