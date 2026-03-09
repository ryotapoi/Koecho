import AppKit
import Speech
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
    @State private var downloadedLocales: [MenuLocaleItem] = []

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
            MenuBarContent(
                appState: appState,
                historyStore: historyStore,
                downloadedLocales: downloadedLocales,
                onTogglePanel: { togglePanel() },
                onSwitchLanguage: { newLocale in
                    if #available(macOS 26, *) {
                        let newKey = SpeechAnalyzerEngine.localeNormalizationKey(newLocale)
                        let currentKey = SpeechAnalyzerEngine.localeNormalizationKey(
                            appState.settings.speechAnalyzerLocale
                        )
                        guard newKey != currentKey else { return }
                    }
                    appState.settings.speechAnalyzerLocale = newLocale
                    Task { @MainActor in
                        await panelController?.switchEngine()
                    }
                }
            )
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
        .onChange(of: appState.settings.speechAnalyzerLocale, initial: true) {
            Task { await refreshDownloadedLocales() }
        }

        Window("Settings", id: "settings") {
            SettingsView(settings: appState.settings, historyStore: historyStore)
                .onDisappear { Task { await refreshDownloadedLocales() } }
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

    private func refreshDownloadedLocales() async {
        guard #available(macOS 26, *),
              appState.settings.effectiveVoiceInputMode == .speechAnalyzer else {
            downloadedLocales = []
            return
        }

        let reserved = await AssetInventory.reservedLocales
        let items = reserved.map { locale -> MenuLocaleItem in
            let identifier = locale.identifier
            let displayName = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
            let key = SpeechAnalyzerEngine.localeNormalizationKey(locale)
            return MenuLocaleItem(identifier: identifier, displayName: displayName, normalizedKey: key)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        downloadedLocales = items

        // Stale selection correction
        if !items.isEmpty {
            let currentKey = SpeechAnalyzerEngine.localeNormalizationKey(
                appState.settings.speechAnalyzerLocale
            )
            let hasMatch = items.contains { $0.normalizedKey == currentKey }
            if !hasMatch, let first = items.first {
                appState.settings.speechAnalyzerLocale = first.identifier
            }
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
    let downloadedLocales: [MenuLocaleItem]
    let onTogglePanel: () -> Void
    let onSwitchLanguage: (String) -> Void
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

        recognitionLanguageMenu

        Button("Copy Last History") {
            historyStore.copyLatestToClipboard()
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

    @ViewBuilder
    private var recognitionLanguageMenu: some View {
        if #available(macOS 26, *),
           appState.settings.effectiveVoiceInputMode == .speechAnalyzer,
           downloadedLocales.count >= 2 {
            let currentKey = SpeechAnalyzerEngine.localeNormalizationKey(
                appState.settings.speechAnalyzerLocale
            )
            Menu("Recognition Language") {
                ForEach(downloadedLocales) { locale in
                    Button {
                        onSwitchLanguage(locale.identifier)
                    } label: {
                        if locale.normalizedKey == currentKey {
                            Text("✓ \(locale.displayName)")
                        } else {
                            Text("  \(locale.displayName)")
                        }
                    }
                }
            }
        }
    }

}

private struct MenuLocaleItem: Identifiable, Equatable {
    let identifier: String
    let displayName: String
    let normalizedKey: String
    var id: String { identifier }
}
