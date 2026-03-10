import AppKit
import KoechoCore
import KoechoPlatform

@MainActor
final class PanelLifecycleManager {
    private let appState: AppState
    private let selectedTextReader: any SelectedTextReading
    private let ducker: any VolumeDucking
    private let panel: InputPanel

    init(
        appState: AppState,
        selectedTextReader: any SelectedTextReading,
        ducker: any VolumeDucking,
        panel: InputPanel
    ) {
        self.appState = appState
        self.selectedTextReader = selectedTextReader
        self.ducker = ducker
        self.panel = panel
    }

    func show() {
        appState.isRunningScript = false
        appState.frontmostApplication = NSWorkspace.shared.frontmostApplication

        if let app = appState.frontmostApplication {
            if let result = selectedTextReader.read(from: app.processIdentifier) {
                appState.selectedText = result.text
                appState.selectionStart = result.start
                appState.selectionEnd = result.end
            } else {
                appState.selectedText = ""
                appState.selectionStart = ""
                appState.selectionEnd = ""
            }
        } else {
            appState.selectedText = ""
            appState.selectionStart = ""
            appState.selectionEnd = ""
        }

        appState.inputText = appState.selectedText
        appState.errorMessage = nil
        appState.isInputPanelVisible = true
        ducker.duck()
        panel.makeKeyAndOrderFront(nil)
    }

    func clearState() {
        ducker.restore()
        appState.inputText = ""
        appState.isInputPanelVisible = false
        appState.frontmostApplication = nil
        appState.selectedText = ""
        appState.selectionStart = ""
        appState.selectionEnd = ""
        appState.errorMessage = nil
        appState.voiceEngineStatus = nil
        appState.isRunningScript = false
        appState.promptScript = nil
        appState.promptText = ""
        appState.pendingReplacementPattern = nil
    }

    func hide() {
        panel.orderOut(nil)
    }
}
