import SwiftUI
import KoechoCore
import KoechoPlatform

struct SettingsView: View {
    @Bindable var settings: KoechoCore.Settings
    let historyStore: HistoryStore
    @State private var selection: SettingsPage = .general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsPage.allCases, selection: $selection) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selection {
            case .general:
                GeneralSettingsView(
                    voiceInput: settings.voiceInput,
                    script: settings.script,
                    replacement: settings.replacement,
                    history: settings.history,
                    paste: settings.paste,
                    volumeDucking: settings.volumeDucking
                )
            case .hotkey:
                HotkeySettingsView(settings: settings.hotkey)
            case .replacementRules:
                ReplacementRuleManagementView(settings: settings.replacement)
            case .scripts:
                ScriptManagementView(settings: settings.script)
            case .history:
                HistoryView(historyStore: historyStore)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case hotkey
    case replacementRules
    case scripts
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .hotkey: String(localized: "Hotkey")
        case .replacementRules: String(localized: "Replacement.sidebar", defaultValue: "Replacement")
        case .scripts: String(localized: "Scripts")
        case .history: String(localized: "History")
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .hotkey: "keyboard"
        case .replacementRules: "arrow.2.squarepath"
        case .scripts: "applescript"
        case .history: "clock.arrow.circlepath"
        }
    }
}
