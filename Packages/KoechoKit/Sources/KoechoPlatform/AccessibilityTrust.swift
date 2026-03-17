import ApplicationServices

/// Check whether the current process is trusted for accessibility.
/// Shared by `LiveAccessibilityClient` and `LiveCGEventClient`.
func checkAccessibilityTrust() -> Bool {
    AXIsProcessTrusted()
}
