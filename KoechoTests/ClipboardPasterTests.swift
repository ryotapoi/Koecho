import AppKit
import Testing
@testable import Koecho

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
}
