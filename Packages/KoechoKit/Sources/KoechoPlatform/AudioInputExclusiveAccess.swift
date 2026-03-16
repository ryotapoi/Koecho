@MainActor
public enum AudioInputExclusiveAccess {
    public private(set) static var isInUse = false

    /// Called before acquiring — stops any active level monitoring.
    private static var onAcquire: (() -> Void)?

    /// Acquire audio input. Stops any active level monitor first.
    public static func acquire() {
        onAcquire?()
        isInUse = true
    }

    /// Release audio input.
    public static func release() {
        isInUse = false
    }

    /// Register a handler that marks this caller as the active level monitor.
    /// The handler is called when another component acquires audio input.
    static func markAsActive(onAcquire handler: @escaping () -> Void) {
        onAcquire = handler
        isInUse = true
    }

    /// Clear the active level monitor state.
    static func clearActive() {
        onAcquire = nil
        isInUse = false
    }
}
