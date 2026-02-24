import Speech
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: Koecho.Settings

    var body: some View {
        Form {
            voiceInputSection
            Section("Clipboard") {
                TextField("Clipboard restore delay (sec)", value: $settings.pasteDelay, format: .number)
            }
            Section("Scripts") {
                TextField("Timeout (sec)", value: $settings.scriptTimeout, format: .number)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Auto-run cycle shortcut")
                        Spacer()
                        ShortcutKeyRecorder(shortcutKey: $settings.autoRunShortcutKey)
                            .frame(width: 120)
                    }
                    Text("Cycle through scripts to auto-run on confirm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Replacement Rules") {
                Toggle("Auto-replace", isOn: $settings.isAutoReplacementEnabled)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Shortcut key")
                        Spacer()
                        ShortcutKeyRecorder(shortcutKey: $settings.replacementShortcutKey)
                            .frame(width: 120)
                    }
                    Text("Avoid shortcuts used by other apps or the system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("History") {
                Toggle("Enable History", isOn: $settings.isHistoryEnabled)
                TextField("Max entries", value: $settings.historyMaxCount, format: .number)
                TextField("Retention days", value: $settings.historyRetentionDays, format: .number)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var voiceInputSection: some View {
        if #available(macOS 26, *) {
            Section("Voice Input") {
                Picker("Engine", selection: $settings.voiceInputMode) {
                    Text("System Dictation").tag(VoiceInputMode.dictation)
                    Text("SpeechAnalyzer (On-device)").tag(VoiceInputMode.speechAnalyzer)
                }
                .pickerStyle(.segmented)
                if settings.voiceInputMode == .speechAnalyzer {
                    SpeechAnalyzerLocalePicker(selection: $settings.speechAnalyzerLocale)
                }
            }
        }
    }
}

// MARK: - SpeechAnalyzerLocalePicker

@available(macOS 26, *)
private struct SpeechAnalyzerLocalePicker: View {
    @Binding var selection: String

    @State private var locales: [LocaleItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading languages…")
                    .controlSize(.small)
            } else if locales.isEmpty {
                TextField("Language", text: $selection)
                    .help("Locale identifier (e.g. ja-JP, en-US)")
            } else {
                Picker("Language", selection: $selection) {
                    ForEach(locales) { locale in
                        Text(locale.label).tag(locale.identifier)
                    }
                }
            }
        }
        .task { await loadLocales() }
    }
}

@available(macOS 26, *)
extension SpeechAnalyzerLocalePicker {
    /// Load supported and installed locales from DictationTranscriber.
    func loadLocales() async {
        let supported = await DictationTranscriber.supportedLocales
        let installed = await DictationTranscriber.installedLocales
        let installedKeys = Set(installed.map { localeNormalizationKey($0) })

        var items = supported.map { locale -> LocaleItem in
            let identifier = locale.identifier
            let displayName = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
            let isInstalled = installedKeys.contains(localeNormalizationKey(locale))
            let label = if isInstalled {
                "\(displayName) (\(identifier))"
            } else {
                "\(displayName) (\(identifier)) — May require download"
            }
            return LocaleItem(identifier: identifier, label: label, sortKey: displayName)
        }
        items.sort { $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending }

        // Validate and fix selection before publishing locales
        if !items.isEmpty {
            let identifiers = Set(items.map(\.identifier))
            if !identifiers.contains(selection) {
                // Try normalized comparison (languageCode + region)
                if let match = findNormalizedMatch(for: selection, in: items) {
                    selection = match.identifier
                } else if let match = findNormalizedMatch(for: "ja-JP", in: items) {
                    selection = match.identifier
                } else {
                    selection = items[0].identifier
                }
            }
        }

        locales = items
        isLoading = false
    }

    private func localeNormalizationKey(_ locale: Locale) -> String {
        let lang = locale.language.languageCode?.identifier ?? ""
        let script = locale.language.script?.identifier ?? ""
        let region = locale.language.region?.identifier ?? ""
        return "\(lang)-\(script)-\(region)"
    }

    private func findNormalizedMatch(for identifier: String, in items: [LocaleItem]) -> LocaleItem? {
        let source = Locale(identifier: identifier)
        let sourceKey = localeNormalizationKey(source)
        return items.first { item in
            localeNormalizationKey(Locale(identifier: item.identifier)) == sourceKey
        }
    }
}

private struct LocaleItem: Identifiable {
    let identifier: String
    let label: String
    let sortKey: String
    var id: String { identifier }
}
