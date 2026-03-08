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
                    SpeechAnalyzerLanguageSection(selection: $settings.speechAnalyzerLocale)
                    AudioInputDeviceSection(
                        deviceUID: $settings.audioInputDeviceUID,
                        deviceName: $settings.audioInputDeviceName
                    )
                }
            }
        }
    }
}

// MARK: - performModelDownload

@available(macOS 26, *)
@MainActor
private func performModelDownload(for identifier: String) async throws -> Bool {
    let localeKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
    let locale = Locale(identifier: identifier)
    let transcriber = DictationTranscriber(locale: locale, preset: SpeechAnalyzerEngine.defaultPreset)

    guard let request = try await AssetInventory.assetInstallationRequest(
        supporting: [transcriber]
    ) else {
        // nil = already installed
        SpeechAnalyzerEngine.markModelVerified(localeKey: localeKey)
        return false
    }

    try await request.downloadAndInstall()
    SpeechAnalyzerEngine.markModelVerified(localeKey: localeKey)
    return true
}

// MARK: - SpeechAnalyzerLanguageSection

@available(macOS 26, *)
private struct SpeechAnalyzerLanguageSection: View {
    @Binding var selection: String

    @State private var allLocales: [LocaleItem] = []
    @State private var isLoading = true
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var isManageSheetPresented = false

    private var reservedLocales: [LocaleItem] {
        allLocales.filter { $0.isReserved }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading languages…")
                    .controlSize(.small)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if reservedLocales.isEmpty {
                        Text("No languages downloaded")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Language", selection: $selection) {
                            ForEach(reservedLocales) { locale in
                                Text(locale.displayLabel).tag(locale.identifier)
                            }
                        }
                    }

                    HStack {
                        Button("Manage Languages…") { isManageSheetPresented = true }
                            .buttonStyle(.link)
                        Spacer()
                        if isDownloading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Downloading model…")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else if let downloadError {
                            Text(downloadError)
                                .font(.caption).foregroundStyle(.red)
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
        .task { await loadLocales() }
        .task(id: selection) {
            guard !isLoading else { return }
            downloadError = nil
            isDownloading = false
            await downloadAsset(for: selection)
        }
        .sheet(isPresented: $isManageSheetPresented, onDismiss: {
            Task { await refreshReservedList() }
        }) {
            LanguageManagementSheet(supportedLocales: allLocales)
        }
    }
}

@available(macOS 26, *)
extension SpeechAnalyzerLanguageSection {
    private func loadLocales() async {
        async let supportedTask = DictationTranscriber.supportedLocales
        async let reservedTask = AssetInventory.reservedLocales
        let supported = await supportedTask
        let reserved = await reservedTask
        let reservedKeys = Set(reserved.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })

        var items = supported.map { locale -> LocaleItem in
            let identifier = locale.identifier
            let displayName = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
            let key = SpeechAnalyzerEngine.localeNormalizationKey(locale)
            return LocaleItem(
                identifier: identifier,
                displayName: displayName,
                sortKey: displayName,
                isReserved: reservedKeys.contains(key)
            )
        }
        items.sort { $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending }

        allLocales = items

        // Validate and fix selection
        if !items.isEmpty {
            let reservedIdentifiers = Set(reservedLocales.map(\.identifier))
            let allIdentifiers = Set(items.map(\.identifier))
            if !reservedIdentifiers.contains(selection), !allIdentifiers.contains(selection) {
                if let match = findNormalizedMatch(for: selection, in: items) {
                    selection = match.identifier
                } else if let match = findNormalizedMatch(for: "ja-JP", in: items) {
                    selection = match.identifier
                } else {
                    selection = items[0].identifier
                }
            }
        }

        isLoading = false
        await downloadAsset(for: selection)
    }

    private func refreshReservedList() async {
        let reserved = await AssetInventory.reservedLocales
        let reservedKeys = Set(reserved.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })

        for i in allLocales.indices {
            let key = SpeechAnalyzerEngine.localeNormalizationKey(allLocales[i].identifier)
            allLocales[i].isReserved = reservedKeys.contains(key)
        }

        let reservedIdentifiers = Set(reservedLocales.map(\.identifier))
        if !reservedIdentifiers.contains(selection) {
            if let first = reservedLocales.first {
                selection = first.identifier
            } else {
                // No reserved locales — trigger auto-download for current selection
                await downloadAsset(for: selection)
            }
        }
    }

    private func downloadAsset(for identifier: String) async {
        guard !Task.isCancelled, selection == identifier else { return }

        let localeKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
        if SpeechAnalyzerEngine.isModelVerified(localeKey: localeKey) {
            return
        }

        do {
            guard !Task.isCancelled, selection == identifier else { return }
            isDownloading = true
            _ = try await performModelDownload(for: identifier)
            guard !Task.isCancelled, selection == identifier else {
                if selection == identifier { isDownloading = false }
                return
            }
            isDownloading = false
            if let index = allLocales.firstIndex(where: { $0.identifier == identifier }) {
                allLocales[index].isReserved = true
            }
        } catch is CancellationError {
            if selection == identifier { isDownloading = false }
        } catch {
            if selection == identifier {
                isDownloading = false
                downloadError = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    private func findNormalizedMatch(for identifier: String, in items: [LocaleItem]) -> LocaleItem? {
        let sourceKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
        return items.first { item in
            SpeechAnalyzerEngine.localeNormalizationKey(item.identifier) == sourceKey
        }
    }
}

// MARK: - LanguageManagementSheet

@available(macOS 26, *)
private struct LanguageManagementSheet: View {
    let supportedLocales: [LocaleItem]

    @Environment(\.dismiss) private var dismiss
    @State private var locales: [LocaleItem] = []
    @State private var downloadingIdentifiers: Set<String> = []
    @State private var errors: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                ForEach(locales) { item in
                    VStack(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.displayName)
                                Text(item.identifier).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if downloadingIdentifiers.contains(item.identifier) {
                                ProgressView().controlSize(.small)
                            } else if item.isReserved {
                                Button("Release") {
                                    Task { await releaseLocale(item) }
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Download") {
                                    Task { await downloadLocale(item) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        if let error = errors[item.identifier] {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Manage Languages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task { locales = supportedLocales; await refreshStatus() }
    }

    private func refreshStatus() async {
        let reserved = await AssetInventory.reservedLocales
        let reservedKeys = Set(reserved.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })
        for i in locales.indices {
            let key = SpeechAnalyzerEngine.localeNormalizationKey(locales[i].identifier)
            locales[i].isReserved = reservedKeys.contains(key)
        }
    }

    private func downloadLocale(_ item: LocaleItem) async {
        downloadingIdentifiers.insert(item.identifier)
        errors[item.identifier] = nil
        do {
            _ = try await performModelDownload(for: item.identifier)
            if let index = locales.firstIndex(where: { $0.identifier == item.identifier }) {
                locales[index].isReserved = true
            }
        } catch {
            errors[item.identifier] = "Download failed: \(error.localizedDescription)"
        }
        downloadingIdentifiers.remove(item.identifier)
    }

    private func releaseLocale(_ item: LocaleItem) async {
        let targetKey = SpeechAnalyzerEngine.localeNormalizationKey(item.identifier)
        let reserved = await AssetInventory.reservedLocales
        guard let reservedLocale = reserved.first(where: {
            SpeechAnalyzerEngine.localeNormalizationKey($0) == targetKey
        }) else { return }

        // Optimistic UI update
        if let index = locales.firstIndex(where: { $0.identifier == item.identifier }) {
            locales[index].isReserved = false
        }
        await AssetInventory.release(reservedLocale: reservedLocale)
        SpeechAnalyzerEngine.invalidateModelCache(for: Locale(identifier: item.identifier))
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
    var isReserved: Bool
    var id: String { identifier }

    var displayLabel: String {
        "\(displayName) (\(identifier))"
    }
}
