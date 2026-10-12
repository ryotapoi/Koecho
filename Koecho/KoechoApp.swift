import AppKit
import KoechoCore
import KoechoPlatform
import SwiftUI
import os

@main
struct KoechoApp: App {
  static let isTesting = NSClassFromString("XCTestCase") != nil
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "App")
  // MenuBarExtra content can be recreated when presented; keep shared state in the App.
  @State private var appState = makeInitialAppState()
  @State private var historyStore = makeInitialHistoryStore()
  @State private var panelController: InputPanelController?
  @State private var hotkeyService: HotkeyService?
  @State private var didPurge = false
  @State private var didShowSettingsLoadAlert = false
  @State private var downloadedLocales: [LocaleItem] = []

  init() {
    guard !Self.isTesting else { return }
    logger.info("Koecho launched")
    requestAccessibilityIfNeeded()
  }

  static func makeInitialAppState(
    isTesting: Bool = isTesting,
    normalDefaults: @autoclosure () -> UserDefaults = .standard,
    testingSuiteName: String? = nil
  ) -> AppState {
    let defaults: UserDefaults
    if isTesting {
      // Select the suite before Settings can read or normalize app preferences.
      // Never fall back to .standard if the isolated suite cannot be created.
      defaults = testingSuiteName.map { UserDefaults(suiteName: $0)! }
        ?? HostedTestDefaults.launch.defaults
    } else {
      defaults = normalDefaults()
    }
    return AppState(settings: Settings(defaults: defaults))
  }

  static func makeInitialHistoryStore(
    isTesting: Bool = isTesting,
    bundleIdentifier: @autoclosure () -> String = Bundle.main.bundleIdentifier!,
    applicationSupportURL: @autoclosure () -> URL = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!,
    testingDirectoryURL: URL = FileManager.default.temporaryDirectory
      .appendingPathComponent("koecho-hosted-history-\(UUID().uuidString)")
  ) -> HistoryStore {
    guard !isTesting else { return HistoryStore(directoryURL: testingDirectoryURL) }
    let identifier = bundleIdentifier()
    let support = applicationSupportURL()
    // The historical name identifies migration eligibility, not the runtime identity.
    let legacyName = "com.ryotapoi.koecho"
    return HistoryStore(
      directoryURL: support.appendingPathComponent(identifier),
      legacyDirectoryURL: identifier.lowercased() == legacyName
        ? support.appendingPathComponent(legacyName) : nil
    )
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
          let newKey = SpeechLocale.normalizationKey(newLocale)
          let currentKey = SpeechLocale.normalizationKey(
            appState.settings.voiceInput.speechAnalyzerLocale
          )
          guard newKey != currentKey else { return }
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
      presentSettingsLoadAlertIfNeeded()
    }
    .onChange(of: appState.settings.hotkey.hotkeyConfig) { _, newConfig in
      guard !Self.isTesting else { return }
      hotkeyService?.updateConfig(newConfig)
    }
    .onChange(of: appState.settings.voiceInput.speechAnalyzerLocale, initial: true) {
      guard !Self.isTesting else { return }
      Task { await refreshDownloadedLocales() }
    }
    .onChange(of: appState.settings.voiceInput.isVoiceInputEnabled) {
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

  private func presentSettingsLoadAlertIfNeeded() {
    guard !Self.isTesting, !didShowSettingsLoadAlert else { return }
    let descriptions = Self.loadFailureDescriptions(
      settingsFailures: appState.settings.orderedLoadFailures,
      historyIsUnavailable: historyStore.isUnavailable
    )
    guard !descriptions.isEmpty else { return }

    didShowSettingsLoadAlert = true
    let alert = NSAlert()
    alert.messageText = String(localized: "Some data could not be loaded")
    alert.informativeText = descriptions.joined(separator: "\n")
    alert.addButton(withTitle: String(localized: "OK"))
    alert.runModal()
  }

  static func loadFailureDescriptions(
    settingsFailures: [SettingsLoadFailure],
    historyIsUnavailable: Bool
  ) -> [String] {
    var descriptions = settingsFailures.map(settingsLoadFailureDescription)
    if historyIsUnavailable {
      descriptions.append(String(localized: "History could not be loaded. It is protected, and new entries are not being recorded. Reset it from the History settings page to resume recording."))
    }
    return descriptions
  }

  private static func settingsLoadFailureDescription(_ failure: SettingsLoadFailure) -> String {
    switch failure {
    case .scripts: String(localized: "Scripts")
    case .autoRunScriptId: String(localized: "Auto-run script")
    case .autoRunShortcut: String(localized: "Auto-run shortcut")
    case .scriptTimeout: String(localized: "Script timeout")
    case .replacementRules: String(localized: "Replacement rules")
    case .replacementAllShortcut: String(localized: .replaceAllShortcut)
    case .replacementShortcut: String(localized: "Replacement shortcut")
    case .isAutoReplacementEnabled: String(localized: "Auto-replace")
    case .voiceInputShortcut: String(localized: "Voice input shortcut")
    }
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
    guard appState.settings.voiceInput.isVoiceInputEnabled else {
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
