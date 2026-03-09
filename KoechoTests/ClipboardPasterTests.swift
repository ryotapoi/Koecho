import AppKit
import Testing
@testable import Koecho

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

@MainActor
struct ClipboardPasterTests {
    private func makeTestPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("com.ryotapoi.koecho.test.\(UUID().uuidString)"))
    }

    @Test func savePasteboardWithString() {
        let pb = makeTestPasteboard()
        pb.clearContents()
        pb.setString("hello", forType: .string)

        let items = savePasteboard(pb)

        #expect(items.count == 1)
        #expect(items[0].types.contains(.string))
        let data = items[0].dataByType[.string]
        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8) == "hello")
    }

    @Test func savePasteboardWithMultipleTypes() {
        let pb = makeTestPasteboard()
        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString("plain text", forType: .string)
        item.setString("<b>html</b>", forType: .html)
        pb.writeObjects([item])

        let items = savePasteboard(pb)

        #expect(items.count == 1)
        #expect(items[0].types.contains(.string))
        #expect(items[0].types.contains(.html))
    }

    @Test func savePasteboardEmpty() {
        let pb = makeTestPasteboard()
        pb.clearContents()

        let items = savePasteboard(pb)

        #expect(items.isEmpty)
    }

    @Test func restorePasteboardRoundTrip() {
        let pb = makeTestPasteboard()
        pb.clearContents()
        pb.setString("original content", forType: .string)

        let saved = savePasteboard(pb)

        pb.clearContents()
        pb.setString("overwritten", forType: .string)

        restorePasteboard(pb, from: saved)

        #expect(pb.string(forType: .string) == "original content")
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

    @Test func clipboardPasterInitWithDelay() {
        let paster = ClipboardPaster(pasteDelay: 3.0)
        #expect(paster.pasteDelay == 3.0)
    }

    @Test func clipboardPasterErrorEquatable() {
        #expect(ClipboardPasterError.accessibilityNotTrusted == ClipboardPasterError.accessibilityNotTrusted)
        #expect(ClipboardPasterError.failedToCreateCGEvent == ClipboardPasterError.failedToCreateCGEvent)
        #expect(ClipboardPasterError.targetAppTerminated == ClipboardPasterError.targetAppTerminated)
        #expect(ClipboardPasterError.accessibilityNotTrusted != ClipboardPasterError.targetAppTerminated)
    }

    @Test func clipboardPasterNotTrustedThrows() async {
        let client = MockCGEventClient()
        client.trusted = false
        let paster = ClipboardPaster(pasteDelay: 0.1, cgEventClient: client)
        let app = NSRunningApplication.current

        await #expect(throws: ClipboardPasterError.accessibilityNotTrusted) {
            try await paster.paste(text: "test", to: app, using: makeTestPasteboard())
        }
    }

    @Test func clipboardPasterCallsSimulatePaste() async throws {
        let client = MockCGEventClient()
        let paster = ClipboardPaster(pasteDelay: 0.1, cgEventClient: client)
        let app = NSRunningApplication.current
        let pb = makeTestPasteboard()

        try await paster.paste(text: "hello", to: app, using: pb)

        #expect(client.simulatePasteCallCount == 1)
    }

    @Test func clipboardPasterSimulatePasteErrorPropagates() async {
        let client = MockCGEventClient()
        client.simulatePasteError = ClipboardPasterError.failedToCreateCGEvent
        let paster = ClipboardPaster(pasteDelay: 0.1, cgEventClient: client)
        let app = NSRunningApplication.current

        await #expect(throws: ClipboardPasterError.failedToCreateCGEvent) {
            try await paster.paste(text: "test", to: app, using: makeTestPasteboard())
        }
    }
}
