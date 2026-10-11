import Foundation

@MainActor
public final class AudioInputExclusiveAccess {
  public static let shared = AudioInputExclusiveAccess()

  public var isInUse: Bool { !recognitionIDs.isEmpty || activeMonitorID != nil }
  private var recognitionIDs: Set<UUID> = []
  private var activeMonitorID: UUID?
  private var onAcquire: (() -> Void)?
  private var releaseHandler: (id: UUID, handler: () -> Void)?

  /// Acquire audio input. Stops any active level monitor first.
  @discardableResult
  public func acquire() -> UUID {
    let id = UUID()
    recognitionIDs.insert(id)
    onAcquire?()
    return id
  }

  /// Release recognition input after its capture has stopped.
  public func release(_ id: UUID) {
    guard recognitionIDs.remove(id) != nil, recognitionIDs.isEmpty else { return }
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
