import AppKit
import os
import SwiftUI

@MainActor
final class InputPanelController {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "InputPanelController")
    private let appState: AppState
    private(set) var panel: InputPanel

    init(appState: AppState) {
        self.appState = appState

        let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))
        let hostingView = NSHostingView(rootView: InputPanelContent(appState: appState))
        panel.contentView = hostingView
        self.panel = panel

        panel.onEscape = { [weak self] in
            self?.cancel()
        }

        panel.center()
        logger.info("InputPanelController initialized")
    }

    func showPanel() {
        if appState.isInputPanelVisible {
            logger.debug("Panel already visible, refocusing")
            panel.makeKeyAndOrderFront(nil)
            return
        }

        appState.frontmostApplication = NSWorkspace.shared.frontmostApplication
        logger.info("Recorded frontmost app: \(self.appState.frontmostApplication?.localizedName ?? "nil", privacy: .public)")

        appState.inputText = ""
        appState.isInputPanelVisible = true
        panel.makeKeyAndOrderFront(nil)

        logger.info("Panel shown, isKeyWindow: \(self.panel.isKeyWindow)")
    }

    func cancel() {
        guard appState.isInputPanelVisible else {
            logger.debug("cancel() called but panel not visible, ignoring")
            return
        }

        appState.inputText = ""
        appState.isInputPanelVisible = false
        appState.frontmostApplication = nil
        panel.orderOut(nil)

        logger.info("Panel cancelled and hidden")
    }
}
