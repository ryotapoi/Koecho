import AppKit
import KoechoCore
import Testing

@testable import KoechoPlatform

private final class MockCGEventClient: CGEventClient, @unchecked Sendable {
  var trusted = true
  var simulatePasteCallCount = 0
  var simulatePasteError: (any Error)?

  func isProcessTrusted() -> Bool { trusted }

  func simulatePaste() throws {
    simulatePasteCallCount += 1
    if let error = simulatePasteError {
      throw error
    }
  }
}

private final class MockClipboardPasteTarget: ClipboardPasteTarget {
  var isTerminated = false
  var localizedName: String? = "Test Target"
  var activateCallCount = 0

  func activate() {
    activateCallCount += 1
  }
}

@MainActor
struct ClipboardPasterTests {
  private func makeTestPasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("com.ryotapoi.koecho.test.\(UUID().uuidString)"))
  }

  private func waitForString(_ expected: String, on pasteboard: NSPasteboard) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while ContinuousClock.now < deadline {
      if pasteboard.string(forType: .string) == expected { return true }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return pasteboard.string(forType: .string) == expected
  }

  @Test func savePasteboardEmpty() {
    let pb = makeTestPasteboard()
    pb.clearContents()
    let items = savePasteboard(pb)
    #expect(items.isEmpty)
  }

  @Test func restorePasteboardMultipleTypes() {
    let pb = makeTestPasteboard()
    pb.clearContents()
    let item = NSPasteboardItem()
    item.setString("text", forType: .string)
    item.setString("<p>html</p>", forType: .html)
    pb.writeObjects([item])
    let saved = savePasteboard(pb)
    pb.clearContents()
    pb.setString("overwritten", forType: .string)
    restorePasteboard(pb, from: saved)
    #expect(pb.string(forType: .string) == "text")
    let htmlData = pb.data(forType: .html)
    #expect(htmlData != nil)
    #expect(String(data: htmlData!, encoding: .utf8) == "<p>html</p>")
  }

  @Test func restorePasteboardFromEmpty() {
    let pb = makeTestPasteboard()
    pb.clearContents()
    pb.setString("something", forType: .string)
    restorePasteboard(pb, from: [])
    #expect(pb.string(forType: .string) == nil)
  }

  @Test func clipboardPasterNotTrustedThrows() async {
    let client = MockCGEventClient()
    client.trusted = false
    let paster = ClipboardPaster(cgEventClient: client)
    let app = NSRunningApplication.current
    await #expect(throws: ClipboardPasterError.accessibilityNotTrusted) {
      try await paster.paste(text: "test", to: app, using: makeTestPasteboard(), pasteDelay: 0.1)
    }
  }

  @Test func clipboardPasterRechecksTrustOnRetry() async throws {
    let client = MockCGEventClient()
    client.trusted = false
    let paster = ClipboardPaster(cgEventClient: client)
    let target = MockClipboardPasteTarget()
    let pasteboard = makeTestPasteboard()

    await #expect(throws: ClipboardPasterError.accessibilityNotTrusted) {
      try await paster.paste(text: "first", to: target, using: pasteboard, pasteDelay: 0.1)
    }

    client.trusted = true
    try await paster.paste(text: "second", to: target, using: pasteboard, pasteDelay: 0.1)

    #expect(client.simulatePasteCallCount == 1)
    #expect(target.activateCallCount == 1)
    #expect(pasteboard.string(forType: .string) == "second")
  }

  @Test func clipboardPasterSimulatePasteErrorPropagates() async {
    let client = MockCGEventClient()
    client.simulatePasteError = ClipboardPasterError.failedToCreateCGEvent
    let paster = ClipboardPaster(cgEventClient: client)
    let target = MockClipboardPasteTarget()
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    await #expect(throws: ClipboardPasterError.failedToCreateCGEvent) {
      try await paster.paste(text: "test", to: target, using: pasteboard, pasteDelay: 0.1)
    }
    #expect(client.simulatePasteCallCount == 1)
    #expect(target.activateCallCount == 1)
    #expect(pasteboard.string(forType: .string) == "test")

    paster.restoreClipboard()
    #expect(pasteboard.string(forType: .string) == "original")
  }

  @Test func clipboardPasterRestoresAfterDelay() async throws {
    let paster = ClipboardPaster(cgEventClient: MockCGEventClient())
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    defer { paster.restoreClipboard() }

    try await paster.paste(
      text: "temporary", to: MockClipboardPasteTarget(), using: pasteboard, pasteDelay: 0.2)
    #expect(pasteboard.string(forType: .string) == "temporary")
    #expect(await waitForString("original", on: pasteboard))
  }

  @Test func clipboardPasterUsesDelayOfEachOperation() async throws {
    let paster = ClipboardPaster(cgEventClient: MockCGEventClient())
    let target = MockClipboardPasteTarget()
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    defer { paster.restoreClipboard() }

    try await paster.paste(text: "first", to: target, using: pasteboard, pasteDelay: 0.1)
    #expect(await waitForString("original", on: pasteboard))
    try await paster.paste(text: "second", to: target, using: pasteboard, pasteDelay: 0.5)
    try await Task.sleep(for: .milliseconds(250))
    #expect(pasteboard.string(forType: .string) == "second")
    #expect(await waitForString("original", on: pasteboard))
  }

  @Test func clipboardPasterRestoresOriginalAfterContinuousPastes() async throws {
    let paster = ClipboardPaster(cgEventClient: MockCGEventClient())
    let target = MockClipboardPasteTarget()
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    defer { paster.restoreClipboard() }

    try await paster.paste(text: "first", to: target, using: pasteboard, pasteDelay: 0.5)
    #expect(pasteboard.string(forType: .string) == "first")

    try await paster.paste(text: "second", to: target, using: pasteboard, pasteDelay: 0.5)
    #expect(pasteboard.string(forType: .string) == "second")
    #expect(await waitForString("original", on: pasteboard))
  }

  @Test(arguments: [false, true], [false, true])
  func clipboardPasterPreservesNewCopy(historyCopy: Bool, immediate: Bool) async throws {
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    let paster = ClipboardPaster(cgEventClient: MockCGEventClient())
    defer { paster.restoreClipboard() }
    try await paster.paste(
      text: "temporary", to: MockClipboardPasteTarget(), using: pasteboard, pasteDelay: 0.15)

    if historyCopy {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      let suite = "ClipboardPasterTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suite)!
      defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
      }
      let history = HistoryStore(directoryURL: directory)
      history.add(text: "new copy", settings: HistorySettings(defaults: defaults))
      #expect(history.copyLatestToClipboard(using: pasteboard))
    } else {
      pasteboard.clearContents()
      pasteboard.setString("new copy", forType: .string)
    }
    let copyCount = pasteboard.changeCount
    if immediate { paster.restoreClipboard() }
    // Observe past the restore deadline, including a cancelled immediate-restore task.
    try await Task.sleep(for: .milliseconds(300))
    #expect(pasteboard.string(forType: .string) == "new copy")
    #expect(pasteboard.changeCount == copyCount)
  }

  @Test func clipboardPasterPreservesSameTextCopiedAgain() async throws {
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    let paster = ClipboardPaster(cgEventClient: MockCGEventClient())
    defer { paster.restoreClipboard() }
    try await paster.paste(
      text: "temporary", to: MockClipboardPasteTarget(), using: pasteboard, pasteDelay: 0.15)
    pasteboard.clearContents()
    pasteboard.setString("temporary", forType: .string)
    let copyCount = pasteboard.changeCount
    try await Task.sleep(for: .milliseconds(300))
    #expect(pasteboard.string(forType: .string) == "temporary")
    #expect(pasteboard.changeCount == copyCount)
  }

  @Test func clipboardPasterRestoresNewCopyAfterNextPaste() async throws {
    let pasteboard = makeTestPasteboard()
    pasteboard.clearContents()
    pasteboard.setString("original", forType: .string)
    let paster = ClipboardPaster(cgEventClient: MockCGEventClient())
    let target = MockClipboardPasteTarget()
    defer { paster.restoreClipboard() }
    try await paster.paste(text: "first", to: target, using: pasteboard, pasteDelay: 0.3)
    pasteboard.clearContents()
    pasteboard.setString("new copy", forType: .string)
    try await paster.paste(text: "second", to: target, using: pasteboard, pasteDelay: 0.3)
    #expect(await waitForString("new copy", on: pasteboard))
  }

  @Test func clipboardPasterTargetTerminatedThrows() async {
    let client = MockCGEventClient()
    let paster = ClipboardPaster(cgEventClient: client)
    let target = MockClipboardPasteTarget()
    target.isTerminated = true
    await #expect(throws: ClipboardPasterError.targetAppTerminated) {
      try await paster.paste(text: "test", to: target, using: makeTestPasteboard(), pasteDelay: 0.1)
    }
    #expect(client.simulatePasteCallCount == 0)
    #expect(target.activateCallCount == 0)
  }
}
