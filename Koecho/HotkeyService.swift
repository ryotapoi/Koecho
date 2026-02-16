import AppKit
import os

@MainActor
final class HotkeyService {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "HotkeyService")
    private var detector = ModifierTapDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onHotkeyActivated: @MainActor () -> Void

    init(onHotkeyActivated: @escaping @MainActor () -> Void) {
        self.onHotkeyActivated = onHotkeyActivated
    }

    func start() {
        guard globalMonitor == nil else { return }

        let eventMask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleEvent(event)
        }

        if globalMonitor == nil {
            logger.warning("Failed to register global event monitor — Input Monitoring permission may be missing")
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleEvent(event)
            return event  // Do not consume the event
        }

        logger.info("Hotkey monitoring started")
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        logger.info("Hotkey monitoring stopped")
    }

    private nonisolated func handleEvent(_ event: NSEvent) {
        let type = event.type
        let keyCode = event.keyCode
        let flags = event.modifierFlags
        let timestamp = event.timestamp

        DispatchQueue.main.async { [weak self] in
            self?.processEvent(type: type, keyCode: keyCode, flags: flags, timestamp: timestamp)
        }
    }

    private func processEvent(
        type: NSEvent.EventType, keyCode: UInt16,
        flags: NSEvent.ModifierFlags, timestamp: TimeInterval
    ) {
        switch type {
        case .flagsChanged:
            let targetFlagIsSet = flags.contains(.function)
            let fired = detector.handleFlagsChanged(
                keyCode: keyCode, targetFlagIsSet: targetFlagIsSet, now: timestamp
            )
            if fired {
                logger.debug("Hotkey tap detected")
                onHotkeyActivated()
            }

        case .keyDown:
            detector.handleKeyDown()

        default:
            break
        }
    }
}
