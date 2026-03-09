import AppKit
@testable import Koecho

@MainActor
final class MockPaster: Pasting {
    var pastedTexts: [String] = []
    var errorToThrow: (any Error)?
    var restoreClipboardCallCount = 0
    var onPaste: (() async -> Void)?

    func paste(text: String, to application: NSRunningApplication, using pasteboard: NSPasteboard) async throws {
        if let error = errorToThrow {
            throw error
        }
        if let onPaste {
            await onPaste()
        }
        pastedTexts.append(text)
    }

    func restoreClipboard() {
        restoreClipboardCallCount += 1
    }
}
