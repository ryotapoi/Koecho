import AppKit
import KoechoCore
import KoechoPlatform
import SwiftUI

struct MenuBarContent: View {
  let appState: AppState
  let historyStore: HistoryStore
  let downloadedLocales: [LocaleItem]
  let onTogglePanel: () -> Void
  let onSwitchLanguage: (String) -> Void
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button(appState.isInputPanelVisible ? "Close Input Panel" : "Open Input Panel") {
      onTogglePanel()
    }

    Menu("Auto-run on Confirm") {
      AutoRunScriptMenuContent(scriptSettings: appState.settings.script)
    }
    .disabled(appState.settings.script.eligibleAutoRunScripts.isEmpty)

    recognitionLanguageMenu

    Button("Copy Last History") {
      historyStore.copyLatestToClipboard()
    }
    .disabled(historyStore.entries.isEmpty)

    Divider()

    Button("Settings...") {
      openWindow(id: "settings")
      Task { @MainActor in
        await bringSettingsWindowToFront()
      }
    }

    Divider()

    Button("Quit Koecho") {
      NSApplication.shared.terminate(nil)
    }
  }

  /// LSUIElement apps can open Settings behind another app after the menu
  /// dismisses, so bump the level while activating the new window.
  @MainActor
  private func bringSettingsWindowToFront() async {
    try? await Task.sleep(for: .milliseconds(100))
    let settingsWindow = NSApplication.shared.windows
      .first { $0.identifier?.rawValue.contains("settings") == true }
    settingsWindow?.level = .floating
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate()
    settingsWindow?.level = .normal
  }

  @ViewBuilder
  private var recognitionLanguageMenu: some View {
    if Self.shouldShowRecognitionLanguageMenu(
      appState: appState,
      downloadedLocales: downloadedLocales
    ) {
      let currentKey = SpeechLocale.normalizationKey(
        appState.settings.voiceInput.speechAnalyzerLocale
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

  static func shouldShowRecognitionLanguageMenu(
    appState: AppState,
    downloadedLocales: [LocaleItem]
  ) -> Bool {
    guard #available(macOS 26, *) else { return false }
    return appState.settings.voiceInput.effectiveVoiceInputMode.usesSpeechAnalyzer
      && downloadedLocales.count >= 2
  }
}

// MARK: - Previews

#Preview("Default") {
  let defaults = UserDefaults(suiteName: "preview-menuBar-default")!
  let settings = KoechoCore.Settings(defaults: defaults)
  settings.voiceInput.voiceInputMode = .dictation
  let appState = AppState(settings: settings)
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("preview-menuBar")
  try? FileManager.default.removeItem(at: dir)
  let store = HistoryStore(directoryURL: dir)
  return MenuBarContent(
    appState: appState,
    historyStore: store,
    downloadedLocales: [],
    onTogglePanel: {},
    onSwitchLanguage: { _ in }
  )
  .frame(width: 250, height: 300)
}
