import AppKit
import KoechoPlatform

@testable import Koecho

@MainActor
final class MockPaster: Pasting {
  var pastedTexts: [String] = []
  var errorToThrow: (any Error)?
  var restoreClipboardCallCount = 0
  var onPaste: (() async -> Void)?
  var suspendsPaste = false
  private var pasteStartedWaiter: CheckedContinuation<Void, Never>?
  private var pasteContinuation: CheckedContinuation<Void, Never>?

  func paste(text: String, to application: NSRunningApplication, using pasteboard: NSPasteboard)
    async throws
  {
    if let error = errorToThrow {
      throw error
    }
    pasteStartedWaiter?.resume()
    pasteStartedWaiter = nil
    if let onPaste {
      await onPaste()
    }
    if suspendsPaste {
      await withCheckedContinuation { pasteContinuation = $0 }
    }
    pastedTexts.append(text)
  }

  func waitForPasteStart() async {
    await withCheckedContinuation { pasteStartedWaiter = $0 }
  }

  func finishPaste() {
    pasteContinuation?.resume()
    pasteContinuation = nil
  }

  func restoreClipboard() {
    restoreClipboardCallCount += 1
  }
}
