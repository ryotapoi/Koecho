import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: Settings

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
                    TextField("Language", text: $settings.speechAnalyzerLocale)
                        .help("Locale identifier (e.g. ja-JP, en-US)")
                }
            }
        }
    }
}
