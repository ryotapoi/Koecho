import AppKit
import SwiftUI
import os

@main
struct KoechoApp: App {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "App")
    @State private var appState = AppState()
    @State private var historyStore = HistoryStore()
    @State private var panelController: InputPanelController?
    @State private var hotkeyService: HotkeyService?
    @State private var didPurge = false

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
            MenuBarContent(appState: appState, onTogglePanel: { togglePanel() })
        }
        .menuBarExtraStyle(.menu)
        .environment(appState)
        .onChange(of: appState.isInputPanelVisible, initial: true) {
            startHotkeyService()
            if !didPurge {
                didPurge = true
                historyStore.purge(
                    maxCount: appState.settings.historyMaxCount,
                    retentionDays: appState.settings.historyRetentionDays
                )
            }
        }

        Window("Settings", id: "settings") {
            SettingsView(settings: appState.settings, historyStore: historyStore)
        }
        .defaultSize(width: 780, height: 460)
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
            let c = InputPanelController(appState: appState, historyStore: historyStore)
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

private struct MenuBarContent: View {
    let appState: AppState
    let onTogglePanel: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(appState.isInputPanelVisible ? "Close Input Panel" : "Open Input Panel") {
            onTogglePanel()
        }

        Divider()

        Button("Settings...") {
            openWindow(id: "settings")
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Koecho") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
