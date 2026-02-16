import AppKit
import os

@MainActor
protocol Pasting {
    func paste(text: String, to application: NSRunningApplication, using pasteboard: NSPasteboard) async throws
    func restoreClipboard()
}

nonisolated enum ClipboardPasterError: Error, Equatable {
    case accessibilityNotTrusted
    case failedToCreateCGEvent
    case targetAppTerminated
}

nonisolated struct PasteboardItem: Sendable {
    let types: [NSPasteboard.PasteboardType]
    let dataByType: [NSPasteboard.PasteboardType: Data]
}

@MainActor
func savePasteboard(_ pasteboard: NSPasteboard) -> [PasteboardItem] {
    guard let items = pasteboard.pasteboardItems else { return [] }
    return items.map { item in
        let types = item.types
        var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
        for type in types {
            if let data = item.data(forType: type) {
                dataByType[type] = data
            }
        }
        return PasteboardItem(types: types, dataByType: dataByType)
    }
}

@MainActor
func restorePasteboard(_ pasteboard: NSPasteboard, from items: [PasteboardItem]) {
    pasteboard.clearContents()
    let pbItems = items.map { item in
        let pbItem = NSPasteboardItem()
        for type in item.types {
            if let data = item.dataByType[type] {
                pbItem.setData(data, forType: type)
            }
        }
        return pbItem
    }
    if !pbItems.isEmpty {
        pasteboard.writeObjects(pbItems)
    }
}

@MainActor
final class ClipboardPaster: Pasting {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "ClipboardPaster")
    let pasteDelay: TimeInterval
    private var restoreTask: Task<Void, Never>?
    private var savedContents: [PasteboardItem]?
    private var savedPasteboard: NSPasteboard?

    nonisolated init(pasteDelay: TimeInterval) {
        self.pasteDelay = pasteDelay
    }

    func paste(
        text: String,
        to application: NSRunningApplication,
        using pasteboard: NSPasteboard = .general
    ) async throws {
        guard AXIsProcessTrusted() else {
            logger.error("Accessibility not trusted")
            throw ClipboardPasterError.accessibilityNotTrusted
        }

        guard !application.isTerminated else {
            logger.error("Target application is terminated")
            throw ClipboardPasterError.targetAppTerminated
        }

        restoreTask?.cancel()
        restoreTask = nil

        if savedContents == nil {
            savedContents = savePasteboard(pasteboard)
            savedPasteboard = pasteboard
            logger.debug("Saved clipboard contents (\(self.savedContents?.count ?? 0) items)")
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        application.activate()
        logger.debug("Activated target app: \(application.localizedName ?? "unknown", privacy: .public)")

        // CancellationError here is safe: clipboard is set but paste won't fire,
        // and the caller's catch block will call restoreClipboard().
        try await Task.sleep(for: .milliseconds(100))

        try simulatePaste()

        let delay = pasteDelay
        let saved = savedContents
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, let saved else { return }
            restorePasteboard(pasteboard, from: saved)
            self.savedContents = nil
            self.savedPasteboard = nil
            self.logger.debug("Clipboard restored after paste")
        }
    }

    func restoreClipboard() {
        restoreTask?.cancel()
        restoreTask = nil

        guard let saved = savedContents, let pasteboard = savedPasteboard else { return }
        restorePasteboard(pasteboard, from: saved)
        savedContents = nil
        savedPasteboard = nil
        logger.debug("Clipboard restored (immediate)")
    }

    private func simulatePaste() throws {
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
