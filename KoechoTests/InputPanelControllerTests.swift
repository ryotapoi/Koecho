import AppKit
import Testing
@testable import Koecho

@MainActor
private final class MockPaster: Pasting {
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

@MainActor
private func makeController(paster: MockPaster? = nil) -> (InputPanelController, AppState, MockPaster) {
    let p = paster ?? MockPaster()
    let appState = AppState()
    let reader = SelectedTextReader()
    let controller = InputPanelController(appState: appState, selectedTextReader: reader, paster: p)
    return (controller, appState, p)
}

@MainActor
struct InputPanelControllerTests {
    @Test func showPanelSetsState() {
        let (controller, appState, _) = makeController()

        controller.showPanel()

        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "")
        #expect(controller.panel.isVisible)
    }

    @Test func cancelClearsState() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "some text"
        controller.cancel()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(appState.frontmostApplication == nil)
        #expect(!controller.panel.isVisible)
    }

    @Test func cancelClearsSelectedText() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.selectedText = "selected"
        appState.selectionStart = "0"
        appState.selectionEnd = "8"
        controller.cancel()

        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
    }

    @Test func cancelClearsTextAfterInput() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello world"
        controller.cancel()

        #expect(appState.inputText == "")
    }

    @Test func showPanelTwicePreservesText() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello"
        controller.showPanel()

        #expect(appState.inputText == "hello")
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func cancelWhenNotVisibleIsNoop() {
        let (controller, appState, _) = makeController()

        controller.cancel()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
    }

    @Test func showCancelShowCycle() {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        #expect(appState.isInputPanelVisible == true)

        controller.cancel()
        #expect(appState.isInputPanelVisible == false)

        controller.showPanel()
        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "")
        #expect(controller.panel.isVisible)
    }

    // MARK: - confirm tests

    @Test func confirmSuccessClearsState() async {
        let paster = MockPaster()
        let (controller, appState, _) = makeController(paster: paster)

        controller.showPanel()
        appState.inputText = "hello"
        // Set a fake frontmost app — use current app as a stand-in
        appState.frontmostApplication = NSRunningApplication.current

        await controller.confirm()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(appState.frontmostApplication == nil)
        #expect(appState.selectedText == "")
        #expect(appState.errorMessage == nil)
        #expect(paster.pastedTexts == ["hello"])
    }

    @Test func confirmFailureShowsError() async {
        let paster = MockPaster()
        paster.errorToThrow = ClipboardPasterError.accessibilityNotTrusted
        let (controller, appState, _) = makeController(paster: paster)

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = NSRunningApplication.current

        await controller.confirm()

        #expect(appState.isInputPanelVisible == true)
        #expect(appState.inputText == "hello")
        #expect(appState.errorMessage != nil)
        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func confirmWithEmptyTextActsAsCancel() async {
        let (controller, appState, paster) = makeController()

        controller.showPanel()
        appState.inputText = "   \n  "

        await controller.confirm()

        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func confirmWhenNotVisibleIsNoop() async {
        let paster = MockPaster()
        let (controller, _, _) = makeController(paster: paster)

        await controller.confirm()

        #expect(paster.pastedTexts.isEmpty)
    }

    @Test func confirmWithNoTargetAppSetsError() async {
        let (controller, appState, _) = makeController()

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = nil

        await controller.confirm()

        #expect(appState.errorMessage == "No target application")
        #expect(appState.isInputPanelVisible == true)
    }

    @Test func cancelDuringConfirmIsIgnored() async {
        let paster = MockPaster()
        let (controller, appState, _) = makeController(paster: paster)

        controller.showPanel()
        appState.inputText = "hello"
        appState.frontmostApplication = NSRunningApplication.current

        // Make paste suspend so we can call cancel() while confirm() is in progress
        paster.onPaste = {
            // Yield to allow cancel() to be attempted on the same actor
            await Task.yield()
        }

        // Start confirm in a Task so we can call cancel() after it begins
        let confirmTask = Task { @MainActor in
            await controller.confirm()
        }
        // Yield to let confirmTask start and reach the onPaste suspension
        await Task.yield()

        // Panel should be hidden (confirm hides it before paste) but isConfirming is true
        // cancel() should be ignored because isConfirming is true
        controller.cancel()

        await confirmTask.value

        // Confirm should have succeeded — cancel was ignored
        #expect(appState.isInputPanelVisible == false)
        #expect(appState.inputText == "")
        #expect(paster.pastedTexts == ["hello"])
    }

    @Test func showPanelClearsSelectedText() {
        let (controller, appState, _) = makeController()

        // Simulate leftover selected text from a previous session
        appState.selectedText = "old selection"
        appState.selectionStart = "5"
        appState.selectionEnd = "18"

        controller.showPanel()

        // In test environment, SelectedTextReader returns nil, so these should be cleared
        #expect(appState.selectedText == "")
        #expect(appState.selectionStart == "")
        #expect(appState.selectionEnd == "")
    }

    @Test func cancelCallsRestoreClipboard() {
        let paster = MockPaster()
        let (controller, _, _) = makeController(paster: paster)

        controller.showPanel()
        controller.cancel()

        #expect(paster.restoreClipboardCallCount == 1)
    }

    @Test func showPanelClearsErrorMessage() {
        let (controller, appState, _) = makeController()

        appState.errorMessage = "previous error"
        controller.showPanel()

        #expect(appState.errorMessage == nil)
    }
}
