import Speech
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: Koecho.Settings

    var body: some View {
        Form {
            voiceInputSection
            volumeDuckingSection
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

    private var volumeDuckingSection: some View {
        Section("Volume Ducking") {
            Toggle("Lower system volume while input panel is open", isOn: $settings.isVolumeDuckingEnabled)
            if settings.isVolumeDuckingEnabled {
                HStack {
                    Text("Target volume")
                    Slider(
                        value: $settings.volumeDuckingLevel,
                        in: 0...1
                    )
                    Text("\(Int(round(settings.volumeDuckingLevel * 100)))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                Text("System output volume will be lowered to this level (or kept as-is if already lower) while the input panel is visible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
                    AudioInputDeviceSection(
                        deviceUID: $settings.audioInputDeviceUID,
                        deviceName: $settings.audioInputDeviceName
                    )
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
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var reservedLocales: [Locale] = []

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading languages…")
                    .controlSize(.small)
            } else if locales.isEmpty {
                TextField("Language", text: $selection)
                    .help("Locale identifier (e.g. ja-JP, en-US)")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Language", selection: $selection) {
                        ForEach(locales) { locale in
                            Text(locale.label).tag(locale.identifier)
                        }
                    }

                    HStack {
                        Spacer()
                        if isDownloading {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading model…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let downloadError {
                            Text(downloadError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if let item = selectedItem, item.isReserved {
                            Button("Release Downloaded Model") {
                                Task { await releaseAsset(for: selection) }
                            }
                            .font(.caption)
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
        .task { await loadLocales() }
        .task(id: selection) {
            guard !isLoading, !locales.isEmpty else { return }
            downloadError = nil
            isDownloading = false
            await downloadAsset(for: selection)
        }
    }

    private var selectedItem: LocaleItem? {
        locales.first { $0.identifier == selection }
    }
}

@available(macOS 26, *)
extension SpeechAnalyzerLocalePicker {
    /// Load supported and installed locales from DictationTranscriber.
    func loadLocales() async {
        let supported = await DictationTranscriber.supportedLocales
        let installed = await DictationTranscriber.installedLocales
        let installedKeys = Set(installed.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })
        let reserved = await AssetInventory.reservedLocales
        let reservedKeys = Set(reserved.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })
        reservedLocales = reserved

        var items = supported.map { locale -> LocaleItem in
            let identifier = locale.identifier
            let displayName = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
            let key = SpeechAnalyzerEngine.localeNormalizationKey(locale)
            return LocaleItem(
                identifier: identifier,
                displayName: displayName,
                sortKey: displayName,
                isInstalled: installedKeys.contains(key),
                isReserved: reservedKeys.contains(key)
            )
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

        // Trigger download for the initial locale.
        // .task(id: selection) may not fire if:
        // - selection didn't change (selectionBefore == selection), or
        // - selection was corrected during isLoading (task ran but hit guard)
        if !items.isEmpty {
            await downloadAsset(for: selection)
        }
    }

    private func findNormalizedMatch(for identifier: String, in items: [LocaleItem]) -> LocaleItem? {
        let sourceKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
        return items.first { item in
            SpeechAnalyzerEngine.localeNormalizationKey(item.identifier) == sourceKey
        }
    }

    private func downloadAsset(for identifier: String) async {
        guard !Task.isCancelled, selection == identifier else { return }

        let locale = Locale(identifier: identifier)
        let transcriber = DictationTranscriber(locale: locale, preset: SpeechAnalyzerEngine.defaultPreset)

        do {
            guard let request = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) else {
                // nil = already installed
                await refreshLocaleStatus()
                return
            }
            guard !Task.isCancelled, selection == identifier else { return }

            isDownloading = true
            try await request.downloadAndInstall()
            guard !Task.isCancelled, selection == identifier else {
                if selection == identifier {
                    isDownloading = false
                }
                return
            }
            isDownloading = false
            await refreshLocaleStatus()
        } catch is CancellationError {
            if selection == identifier {
                isDownloading = false
            }
        } catch {
            if selection == identifier {
                isDownloading = false
                downloadError = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    private func releaseAsset(for identifier: String) async {
        let targetKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
        guard let reservedLocale = reservedLocales.first(where: {
            SpeechAnalyzerEngine.localeNormalizationKey($0) == targetKey
        }) else { return }

        // Update UI immediately (prevent double-tap + responsive feedback)
        if let index = locales.firstIndex(where: { $0.identifier == identifier }) {
            locales[index].isReserved = false
        }
        await AssetInventory.release(reservedLocale: reservedLocale)
        SpeechAnalyzerEngine.invalidateModelCache(for: Locale(identifier: identifier))
        await refreshLocaleStatus()
    }

    private func refreshLocaleStatus() async {
        let installed = await DictationTranscriber.installedLocales
        let installedKeys = Set(installed.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })
        let reserved = await AssetInventory.reservedLocales
        let reservedKeys = Set(reserved.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })
        reservedLocales = reserved

        for i in locales.indices {
            let key = SpeechAnalyzerEngine.localeNormalizationKey(locales[i].identifier)
            locales[i].isInstalled = installedKeys.contains(key)
            locales[i].isReserved = reservedKeys.contains(key)
        }
    }
}

// MARK: - AudioInputDeviceSection

@available(macOS 26, *)
private struct AudioInputDeviceSection: View {
    @Binding var deviceUID: String?
    @Binding var deviceName: String?
    @State private var deviceManager = AudioDeviceManager()

    private var isSelectedDeviceDisconnected: Bool {
        guard let uid = deviceUID else { return false }
        return !deviceManager.inputDevices.contains { $0.uid == uid }
    }

    var body: some View {
        Picker("Microphone", selection: $deviceUID) {
            Text("System Default").tag(String?.none)
            ForEach(deviceManager.inputDevices) { device in
                Text(device.name).tag(Optional(device.uid))
            }
            if isSelectedDeviceDisconnected, let uid = deviceUID {
                Text("\(deviceName ?? "Unknown device") (not connected)")
                    .foregroundStyle(.secondary)
                    .tag(Optional(uid))
            }
        }
        .onChange(of: deviceUID) { _, newUID in
            if let newUID,
               let device = deviceManager.inputDevices.first(where: { $0.uid == newUID }) {
                deviceName = device.name
            } else if newUID == nil {
                deviceName = nil
            }
            deviceManager.startMonitoring(deviceUID: newUID)
        }

        if isSelectedDeviceDisconnected {
            Text("Selected device is not available. Using system default.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if deviceManager.monitoredDeviceSupportsVolume {
            HStack {
                Image(systemName: "mic")
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { deviceManager.inputVolume },
                        set: { deviceManager.setInputVolume($0) }
                    ),
                    in: 0...1
                )
                Image(systemName: "mic.fill")
                    .foregroundStyle(.secondary)
            }
        }

        InputLevelMeter(level: deviceManager.inputLevel)
            .onAppear { deviceManager.startMonitoring(deviceUID: deviceUID) }
            .onDisappear { deviceManager.stopMonitoring() }
    }
}

// MARK: - InputLevelMeter

private struct InputLevelMeter: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            Text("Input Level")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .animation(.linear(duration: 0.1), value: level)
            }
            .frame(height: 6)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
            )
        }
    }

    private var levelColor: Color {
        if level > 0.9 { .red }
        else if level > 0.7 { .yellow }
        else { .green }
    }
}

private struct LocaleItem: Identifiable {
    let identifier: String
    let displayName: String
    let sortKey: String
    var isInstalled: Bool
    var isReserved: Bool
    var id: String { identifier }

    var label: String {
        if isInstalled {
            "\(displayName) (\(identifier))"
        } else {
            "\(displayName) (\(identifier)) — Download required"
        }
    }
}
