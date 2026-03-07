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
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility trusted: \(trusted)")
    }

    var body: some Scene {
        MenuBarExtra("Koecho", image: "MenuBarIcon") {
            MenuBarContent(appState: appState, historyStore: historyStore, onTogglePanel: { togglePanel() })
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
        .onChange(of: appState.settings.hotkeyConfig) { _, newConfig in
            hotkeyService?.updateConfig(newConfig)
        }

        Window("Settings", id: "settings") {
            SettingsView(settings: appState.settings, historyStore: historyStore)
        }
        .defaultSize(width: 780, height: 460)
    }

    private func startHotkeyService() {
        guard hotkeyService == nil else { return }
        let service = HotkeyService(
            hotkeyConfig: appState.settings.hotkeyConfig,
            isPanelVisible: { [appState] in appState.isInputPanelVisible },
            onSingleTap: { handleSingleTap() },
            onDoubleTap: { handleDoubleTap() }
        )
        service.start()
        hotkeyService = service
    }

    private func ensurePanelController() -> InputPanelController {
        if let existing = panelController { return existing }
        let controller = InputPanelController(appState: appState, historyStore: historyStore)
        panelController = controller
        return controller
    }

    private func handleSingleTap() {
        switch appState.settings.hotkeyConfig.tapMode {
        case .singleToggle:
            togglePanel()
        case .doubleTapToShow:
            guard appState.isInputPanelVisible else { return }
            let controller = ensurePanelController()
            Task { @MainActor in await controller.confirm() }
        }
    }

    private func handleDoubleTap() {
        let controller = ensurePanelController()
        if !appState.isInputPanelVisible {
            controller.showPanel()
        } else {
            Task { @MainActor in await controller.confirm() }
        }
    }

    private func togglePanel() {
        let controller = ensurePanelController()

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
    let historyStore: HistoryStore
    let onTogglePanel: () -> Void
    @Environment(\.openWindow) private var openWindow

    private var eligibleScripts: [Script] {
        appState.settings.scripts.filter { !$0.requiresPrompt }
    }

    var body: some View {
        Button(appState.isInputPanelVisible ? "Close Input Panel" : "Open Input Panel") {
            onTogglePanel()
        }

        Menu("Auto-run on Confirm") {
            Button {
                appState.settings.autoRunScriptId = nil
            } label: {
                if appState.settings.autoRunScriptId == nil {
                    Text("✓ None")
                } else {
                    Text("  None")
                }
            }
            Divider()
            ForEach(eligibleScripts) { script in
                Button {
                    appState.settings.autoRunScriptId = script.id
                } label: {
                    if appState.settings.autoRunScriptId == script.id {
                        Text("✓ \(script.name)")
                    } else {
                        Text("  \(script.name)")
                    }
                }
            }
        }
        .disabled(eligibleScripts.isEmpty)

        Button("Copy Last History") {
            if let entry = historyStore.entries.first {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
            }
        }
        .disabled(historyStore.entries.isEmpty)

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
