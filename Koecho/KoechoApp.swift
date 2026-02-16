import AppKit
import SwiftUI
import os

@main
struct KoechoApp: App {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "App")
    @State private var appState = AppState()
    @State private var panelController: InputPanelController?
    @State private var hotkeyService: HotkeyService?

    init() {
        logger.info("Koecho launched")
        requestAccessibilityIfNeeded()
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility trusted: \(trusted)")
    }

    var body: some Scene {
        MenuBarExtra("Koecho", systemImage: "mic.fill") {
            Button(appState.isInputPanelVisible ? "Close Input Panel" : "Open Input Panel") {
                togglePanel()
            }

            Divider()

            Button("Quit Koecho") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
        .environment(appState)
        .onChange(of: appState.isInputPanelVisible, initial: true) {
            startHotkeyService()
        }
    }

    private func startHotkeyService() {
        guard hotkeyService == nil else { return }
        let service = HotkeyService {
            togglePanel()
        }
        service.start()
        hotkeyService = service
    }

    private func togglePanel() {
        let controller = panelController ?? {
            let c = InputPanelController(appState: appState)
            panelController = c
            return c
        }()

        if appState.isInputPanelVisible {
            Task { @MainActor in
                await controller.confirm()
            }
        } else {
            controller.showPanel()
        }
    }
}
