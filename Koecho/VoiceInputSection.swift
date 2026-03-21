import SwiftUI
import Speech
import KoechoCore
import KoechoPlatform

struct VoiceInputSection: View {
    @Bindable var voiceInput: VoiceInputSettings

    var body: some View {
        Section("Voice Input") {
            if #available(macOS 26, *) {
                Picker("Engine", selection: $voiceInput.voiceInputMode) {
                    Text("Off").tag(VoiceInputMode.off)
                    Text("System Dictation").tag(VoiceInputMode.dictation)
                    Text("SpeechAnalyzer (On-device)").tag(VoiceInputMode.speechAnalyzer)
                }
                .pickerStyle(.segmented)
                if voiceInput.voiceInputMode == .speechAnalyzer {
                    SpeechAnalyzerLanguageSection(selection: $voiceInput.speechAnalyzerLocale)
                    AudioInputDeviceSection(
                        deviceUID: $voiceInput.audioInputDeviceUID,
                        deviceName: $voiceInput.audioInputDeviceName
                    )
                }
            } else {
                Toggle("Voice input", isOn: Binding(
                    get: { voiceInput.voiceInputMode != .off },
                    set: { voiceInput.voiceInputMode = $0 ? .dictation : .off }
                ))
            }
        }
    }
}

// MARK: - SpeechAnalyzerLanguageSection

@available(macOS 26, *)
private struct SpeechAnalyzerLanguageSection: View {
    @Binding var selection: String

    @State private var manager = SpeechAnalyzerLocaleManager()
    @State private var isManageSheetPresented = false

    var body: some View {
        Group {
            if manager.isLoading {
                ProgressView("Loading languages…")
                    .controlSize(.small)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if manager.reservedLocales.isEmpty {
                        Text("No languages downloaded")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Language", selection: $selection) {
                            ForEach(manager.reservedLocales) { locale in
                                Text(locale.displayLabel).tag(locale.identifier)
                            }
                        }
                    }

                    HStack {
                        Button("Manage Languages…") { isManageSheetPresented = true }
                            .buttonStyle(.link)
                        Spacer()
                        if manager.isDownloading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Downloading model…")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else if let downloadError = manager.downloadError {
                            Text(downloadError)
                                .font(.caption).foregroundStyle(.red)
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
        .task {
            if let corrected = await manager.loadLocales(currentSelection: selection) {
                selection = corrected
            }
        }
        .task(id: selection) {
            guard !manager.isLoading else { return }
            manager.clearDownloadError()
            await manager.downloadAsset(for: selection, currentSelection: selection)
        }
        .sheet(isPresented: $isManageSheetPresented, onDismiss: {
            Task {
                if let corrected = await manager.refreshReservedList(currentSelection: selection) {
                    selection = corrected
                }
            }
        }) {
            LanguageManagementSheet(manager: manager)
        }
    }
}

// MARK: - LanguageManagementSheet

@available(macOS 26, *)
private struct LanguageManagementSheet: View {
    let manager: SpeechAnalyzerLocaleManager

    @Environment(\.dismiss) private var dismiss
    @State private var downloadingIdentifiers: Set<String> = []
    @State private var errors: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.allLocales) { item in
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
    }

    private func downloadLocale(_ item: LocaleItem) async {
        downloadingIdentifiers.insert(item.identifier)
        errors[item.identifier] = nil
        do {
            try await manager.downloadLocale(item)
        } catch {
            errors[item.identifier] = String(localized: "Download failed: \(error.localizedDescription)")
        }
        downloadingIdentifiers.remove(item.identifier)
    }

    private func releaseLocale(_ item: LocaleItem) async {
        await manager.releaseLocale(item)
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
