import AppKit
import KoechoCore
import KoechoPlatform
import SwiftUI
import os

@main
struct KoechoApp: App {
  private static let isTesting = NSClassFromString("XCTestCase") != nil
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "App")
  @State private var appState = AppState()
  @State private var historyStore = HistoryStore()
  @State private var panelController: InputPanelController?
  @State private var hotkeyService: HotkeyService?
  @State private var didPurge = false
  @State private var downloadedLocales: [LocaleItem] = []

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
            let newKey = SpeechLocale.normalizationKey(newLocale)
            let currentKey = SpeechLocale.normalizationKey(
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
    .onChange(of: appState.settings.appIcon.selectedAppIcon, initial: true) {
      guard !Self.isTesting else { return }
      AppIconApplicator.apply(appState.settings.appIcon.selectedAppIcon)
    }

    Window("Settings", id: "settings") {
      SettingsView(
        settings: appState.settings,
        historyStore: historyStore,
        onSpeechLocalesChanged: { await refreshDownloadedLocales() }
      )
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
      appState.settings.voiceInput.effectiveVoiceInputMode.usesSpeechAnalyzer
    else {
      downloadedLocales = []
      return
    }

    let manager = SpeechAnalyzerLocaleManager()
    let items = await manager.refreshMenuLocales()
    downloadedLocales = items

    // Menu items carry AssetInventory-form identifiers, which can differ in
    // string form from the supportedLocales-form identifiers the Settings
    // Picker uses as tags. Only correct when no normalized match exists, so
    // a valid selection is never rewritten into the other identifier form.
    let current = appState.settings.voiceInput.speechAnalyzerLocale
    if manager.findNormalizedMatch(for: current, in: items) == nil,
      let corrected = manager.correctSelection(currentSelection: current, items: items)
    {
      appState.settings.voiceInput.speechAnalyzerLocale = corrected
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
