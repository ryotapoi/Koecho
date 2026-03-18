import AppKit
import Speech
import SwiftUI
import os
import KoechoCore
import KoechoPlatform

@main
struct KoechoApp: App {
    private static let isTesting = NSClassFromString("XCTestCase") != nil
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "App")
    @State private var appState = AppState()
    @State private var historyStore = HistoryStore()
    @State private var panelController: InputPanelController?
    @State private var hotkeyService: HotkeyService?
    @State private var didPurge = false
    @State private var downloadedLocales: [MenuLocaleItem] = []

    init() {
        guard !Self.isTesting else { return }
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
                            appState.settings.voiceInput.speechAnalyzerLocale
                        )
                        guard newKey != currentKey else { return }
                    }
                    appState.settings.voiceInput.speechAnalyzerLocale = newLocale
                    Task { @MainActor in
                        await panelController?.switchEngine()
                    }
                }
            )
        }
        .menuBarExtraStyle(.menu)
        .environment(appState)
        .onChange(of: appState.isInputPanelVisible, initial: true) {
            guard !Self.isTesting else { return }
            startHotkeyService()
            if !didPurge {
                didPurge = true
                historyStore.purge(
                    maxCount: appState.settings.history.historyMaxCount,
                    retentionDays: appState.settings.history.historyRetentionDays
                )
            }
        }
        .onChange(of: appState.settings.hotkey.hotkeyConfig) { _, newConfig in
            guard !Self.isTesting else { return }
            hotkeyService?.updateConfig(newConfig)
        }
        .onChange(of: appState.settings.voiceInput.speechAnalyzerLocale, initial: true) {
            guard !Self.isTesting else { return }
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
            hotkeyConfig: appState.settings.hotkey.hotkeyConfig,
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
        switch appState.settings.hotkey.hotkeyConfig.tapMode {
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
              appState.settings.voiceInput.effectiveVoiceInputMode == .speechAnalyzer else {
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
                appState.settings.voiceInput.speechAnalyzerLocale
            )
            let hasMatch = items.contains { $0.normalizedKey == currentKey }
            if !hasMatch, let first = items.first {
                appState.settings.voiceInput.speechAnalyzerLocale = first.identifier
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
