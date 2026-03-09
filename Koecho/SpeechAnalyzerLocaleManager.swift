import Speech
import os

struct LocaleItem: Identifiable {
    let identifier: String
    let displayName: String
    let sortKey: String
    var isReserved: Bool
    var id: String { identifier }

    var displayLabel: String {
        "\(displayName) (\(identifier))"
    }
}

@available(macOS 26, *)
@MainActor @Observable
final class SpeechAnalyzerLocaleManager {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "SpeechAnalyzerLocaleManager")

    private(set) var allLocales: [LocaleItem] = []
    private(set) var isLoading = true
    private(set) var isDownloading = false
    private(set) var downloadError: String?

    var reservedLocales: [LocaleItem] {
        allLocales.filter { $0.isReserved }
    }

    func loadLocales(currentSelection: String) async -> String? {
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
        var correctedSelection: String?
        if !items.isEmpty {
            let reservedIdentifiers = Set(reservedLocales.map(\.identifier))
            let allIdentifiers = Set(items.map(\.identifier))
            if !reservedIdentifiers.contains(currentSelection), !allIdentifiers.contains(currentSelection) {
                if let match = findNormalizedMatch(for: currentSelection, in: items) {
                    correctedSelection = match.identifier
                } else if let match = findNormalizedMatch(for: "ja-JP", in: items) {
                    correctedSelection = match.identifier
                } else {
                    correctedSelection = items[0].identifier
                }
            }
        }

        isLoading = false

        let effectiveSelection = correctedSelection ?? currentSelection
        await downloadAsset(for: effectiveSelection, currentSelection: effectiveSelection)

        return correctedSelection
    }

    func refreshReservedList(currentSelection: String) async -> String? {
        let reserved = await AssetInventory.reservedLocales
        let reservedKeys = Set(reserved.map { SpeechAnalyzerEngine.localeNormalizationKey($0) })

        for i in allLocales.indices {
            let key = SpeechAnalyzerEngine.localeNormalizationKey(allLocales[i].identifier)
            allLocales[i].isReserved = reservedKeys.contains(key)
        }

        let reservedIdentifiers = Set(reservedLocales.map(\.identifier))
        if !reservedIdentifiers.contains(currentSelection) {
            if let first = reservedLocales.first {
                return first.identifier
            } else {
                // No reserved locales — trigger auto-download for current selection
                await downloadAsset(for: currentSelection, currentSelection: currentSelection)
                return nil
            }
        }
        return nil
    }

    func downloadAsset(for identifier: String, currentSelection: String) async {
        guard !Task.isCancelled, currentSelection == identifier else { return }

        let localeKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
        if SpeechAnalyzerEngine.isModelVerified(localeKey: localeKey) {
            return
        }

        do {
            guard !Task.isCancelled, currentSelection == identifier else { return }
            isDownloading = true
            _ = try await performModelDownload(for: identifier)
            guard !Task.isCancelled, currentSelection == identifier else {
                if currentSelection == identifier { isDownloading = false }
                return
            }
            isDownloading = false
            if let index = allLocales.firstIndex(where: { $0.identifier == identifier }) {
                allLocales[index].isReserved = true
            }
        } catch is CancellationError {
            if currentSelection == identifier { isDownloading = false }
        } catch {
            if currentSelection == identifier {
                isDownloading = false
                downloadError = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    func downloadLocale(_ item: LocaleItem) async throws {
        _ = try await performModelDownload(for: item.identifier)
        if let index = allLocales.firstIndex(where: { $0.identifier == item.identifier }) {
            allLocales[index].isReserved = true
        }
    }

    func releaseLocale(_ item: LocaleItem) async {
        let targetKey = SpeechAnalyzerEngine.localeNormalizationKey(item.identifier)
        let reserved = await AssetInventory.reservedLocales
        guard let reservedLocale = reserved.first(where: {
            SpeechAnalyzerEngine.localeNormalizationKey($0) == targetKey
        }) else { return }

        // Optimistic UI update
        if let index = allLocales.firstIndex(where: { $0.identifier == item.identifier }) {
            allLocales[index].isReserved = false
        }
        await AssetInventory.release(reservedLocale: reservedLocale)
        SpeechAnalyzerEngine.invalidateModelCache(for: Locale(identifier: item.identifier))
    }

    func clearDownloadError() {
        downloadError = nil
    }

    func findNormalizedMatch(for identifier: String, in items: [LocaleItem]) -> LocaleItem? {
        let sourceKey = SpeechAnalyzerEngine.localeNormalizationKey(identifier)
        return items.first { item in
            SpeechAnalyzerEngine.localeNormalizationKey(item.identifier) == sourceKey
        }
    }

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
}
