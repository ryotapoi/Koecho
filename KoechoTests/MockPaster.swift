import AppKit
import KoechoPlatform

@testable import Koecho

@MainActor
final class MockPaster: Pasting {
  var pastedDelays: [TimeInterval] = []
  var pastedTexts: [String] = []
  var pastedApplications: [NSRunningApplication] = []
  var errorToThrow: (any Error)?
  var restoreClipboardCallCount = 0
  var onPasteAttempt: (() -> Void)?
  var suspendsPaste = false
  private var pasteStartedWaiter: CheckedContinuation<Void, Never>?
  private var pasteContinuation: CheckedContinuation<Void, Never>?

  func paste(
    text: String, to application: NSRunningApplication, using pasteboard: NSPasteboard,
    pasteDelay: TimeInterval
  ) async throws
  {
    pastedDelays.append(pasteDelay)
    pastedApplications.append(application)
    onPasteAttempt?()
    if let error = errorToThrow {
      throw error
    }
    pasteStartedWaiter?.resume()
    pasteStartedWaiter = nil
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
