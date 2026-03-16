import AppKit
import KoechoCore
import os

@MainActor
public final class HotkeyService {
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "HotkeyService")
    public private(set) var detector: ModifierTapDetector
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var doubleTapTimer: DispatchSourceTimer?

    private var config: HotkeyConfig
    private let isPanelVisible: @MainActor () -> Bool
    private let onSingleTap: @MainActor () -> Void
    private let onDoubleTap: @MainActor () -> Void

    public init(
        hotkeyConfig: HotkeyConfig,
        isPanelVisible: @escaping @MainActor () -> Bool,
        onSingleTap: @escaping @MainActor () -> Void,
        onDoubleTap: @escaping @MainActor () -> Void
    ) {
        self.config = hotkeyConfig
        self.isPanelVisible = isPanelVisible
        self.onSingleTap = onSingleTap
        self.onDoubleTap = onDoubleTap
        self.detector = ModifierTapDetector()
        self.detector.targetKeyCode = hotkeyConfig.keyCode
    }

    public func start() {
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
            return event
        }

        logger.info("Hotkey monitoring started")
    }

    public func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        cancelDoubleTapTimer()
        logger.info("Hotkey monitoring stopped")
    }

    public func updateConfig(_ newConfig: HotkeyConfig) {
        config = newConfig
        detector.targetKeyCode = newConfig.keyCode
        detector.state = .idle
        cancelDoubleTapTimer()
        logger.info("Hotkey config updated: \(newConfig.modifierKey.rawValue) \(newConfig.side.rawValue) \(newConfig.tapMode.rawValue)")
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

    public func processEvent(
        type: NSEvent.EventType, keyCode: UInt16,
        flags: NSEvent.ModifierFlags, timestamp: TimeInterval
    ) {
        switch type {
        case .flagsChanged:
            let targetFlagIsSet = flags.contains(config.modifierFlag)
            let tapResult = detector.handleFlagsChanged(
                keyCode: keyCode, targetFlagIsSet: targetFlagIsSet, now: timestamp
            )

            switch tapResult {
            case .singleTap:
                logger.debug("Single tap detected")
                onSingleTap()
            case .doubleTap:
                cancelDoubleTapTimer()
                logger.debug("Double tap detected")
                onDoubleTap()
            case .none:
                break
            }

            // If detector entered waitingForSecondTap, decide whether to start timer or expire immediately
            if tapResult == .none, case .waitingForSecondTap = detector.state, doubleTapTimer == nil {
                if config.tapMode == .singleToggle || isPanelVisible() {
                    // No need to wait for double tap — expire immediately
                    let expireResult = detector.expireDoubleTapWindow()
                    if expireResult == .singleTap {
                        logger.debug("Single tap detected (immediate expire)")
                        onSingleTap()
                    }
                } else {
                    startDoubleTapTimer()
                }
            }

        case .keyDown:
            detector.handleKeyDown()
            cancelDoubleTapTimer()

        default:
            break
        }
    }

    private func startDoubleTapTimer() {
        cancelDoubleTapTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + detector.doubleTapInterval)
        timer.setEventHandler { [weak self] in
            self?.handleDoubleTapTimerFired()
        }
        doubleTapTimer = timer
        timer.resume()
    }

    private func handleDoubleTapTimerFired() {
        doubleTapTimer = nil
        let result = detector.expireDoubleTapWindow()
        if result == .singleTap {
            logger.debug("Single tap detected (timer expired)")
            onSingleTap()
        }
    }

    private func cancelDoubleTapTimer() {
        doubleTapTimer?.cancel()
        doubleTapTimer = nil
    }
}
