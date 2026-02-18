import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    let historyStore: HistoryStore
    @State private var selection: SettingsPage = .general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsPage.allCases, selection: $selection) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selection {
            case .general:
                GeneralSettingsView(settings: settings)
            case .replacementRules:
                ReplacementRuleManagementView(settings: settings)
            case .scripts:
                ScriptManagementView(settings: settings)
            case .history:
                HistoryView(historyStore: historyStore)
            }
        }
    }
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case replacementRules
    case scripts
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .replacementRules: "Replacement Rules"
        case .scripts: "Scripts"
        case .history: "History"
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .replacementRules: "arrow.2.squarepath"
        case .scripts: "applescript"
        case .history: "clock.arrow.circlepath"
        }
    }
}
