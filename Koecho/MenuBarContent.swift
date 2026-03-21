import SwiftUI
import AppKit
import KoechoCore
import KoechoPlatform

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
            Task {
                NSApplication.shared.activate()
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
           appState.settings.voiceInput.effectiveVoiceInputMode == .speechAnalyzer,
           downloadedLocales.count >= 2 {
            let currentKey = SpeechAnalyzerEngine.localeNormalizationKey(
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
}
