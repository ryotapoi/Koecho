import CoreGraphics
import KoechoCore
import os

public protocol CGEventClient: Sendable {
    func isProcessTrusted() -> Bool
    func simulatePaste() throws
}

public nonisolated struct LiveCGEventClient: CGEventClient {
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "CGEventClient")

    public init() {}

    public func isProcessTrusted() -> Bool {
        checkAccessibilityTrust()
    }

    public func simulatePaste() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger.error("Failed to create CGEventSource")
            throw ClipboardPasterError.failedToCreateCGEvent
        }

        // Key code 9 = V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            logger.error("Failed to create CGEvent for Cmd+V")
            throw ClipboardPasterError.failedToCreateCGEvent
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        logger.debug("Simulated Cmd+V paste")
    }
}
