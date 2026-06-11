import KoechoCore
import Observation
import Speech
import os

public struct LocaleItem: Identifiable, Sendable, Equatable {
  public let identifier: String
  public let displayName: String
  public let sortKey: String
  public let normalizedKey: String
  public var isReserved: Bool
  public var id: String { identifier }

  public var displayLabel: String {
    "\(displayName) (\(identifier))"
  }

  public init(
    identifier: String, displayName: String, sortKey: String, normalizedKey: String,
    isReserved: Bool
  ) {
    self.identifier = identifier
    self.displayName = displayName
    self.sortKey = sortKey
    self.normalizedKey = normalizedKey
    self.isReserved = isReserved
  }
}

@available(macOS 26, *)
@MainActor @Observable
public final class SpeechAnalyzerLocaleManager {
  private let logger = Logger(
    subsystem: Logger.koechoSubsystem, category: "SpeechAnalyzerLocaleManager")

  public private(set) var allLocales: [LocaleItem] = []
  public private(set) var isLoading = true
  public private(set) var isDownloading = false
  public private(set) var downloadError: String?

  public init() {}

  public var reservedLocales: [LocaleItem] {
    allLocales.filter { $0.isReserved }
  }

  public func loadLocales(currentSelection: String) async -> String? {
    async let supportedTask = DictationTranscriber.supportedLocales
    async let reservedTask = AssetInventory.reservedLocales
    let supported = await supportedTask
    let reserved = await reservedTask
    let reservedKeys = Set(reserved.map { SpeechLocale.normalizationKey($0) })

    var items = supported.map { locale -> LocaleItem in
      let key = SpeechLocale.normalizationKey(locale)
      return makeLocaleItem(
        from: locale, normalizedKey: key, isReserved: reservedKeys.contains(key))
    }
    items.sort { $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending }

    allLocales = items

    let correctedSelection = correctSelection(currentSelection: currentSelection, items: items)

    isLoading = false

    let effectiveSelection = correctedSelection ?? currentSelection
    await downloadAsset(for: effectiveSelection, currentSelection: effectiveSelection)

    return correctedSelection
  }

  public func refreshReservedList(currentSelection: String) async -> String? {
    let reserved = await AssetInventory.reservedLocales
    let reservedKeys = Set(reserved.map { SpeechLocale.normalizationKey($0) })

    for i in allLocales.indices {
      allLocales[i].isReserved = reservedKeys.contains(allLocales[i].normalizedKey)
    }

    let reservedItems = reservedLocales
    guard !reservedItems.isEmpty else {
      // No reserved locales — trigger auto-download for current selection
      await downloadAsset(for: currentSelection, currentSelection: currentSelection)
      return nil
    }
    return correctSelection(currentSelection: currentSelection, items: reservedItems)
  }

  public func downloadAsset(for identifier: String, currentSelection: String) async {
    guard !Task.isCancelled, currentSelection == identifier else { return }

    let localeKey = SpeechLocale.normalizationKey(identifier)
    if SpeechModelVerificationCache.isVerified(localeKey: localeKey) {
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

  public func downloadLocale(_ item: LocaleItem) async throws {
    _ = try await performModelDownload(for: item.identifier)
    if let index = allLocales.firstIndex(where: { $0.identifier == item.identifier }) {
      allLocales[index].isReserved = true
    }
  }

  public func releaseLocale(_ item: LocaleItem) async {
    let targetKey = SpeechLocale.normalizationKey(item.identifier)
    let reserved = await AssetInventory.reservedLocales
    guard
      let reservedLocale = reserved.first(where: {
        SpeechLocale.normalizationKey($0) == targetKey
      })
    else { return }

    // Optimistic UI update
    if let index = allLocales.firstIndex(where: { $0.identifier == item.identifier }) {
      allLocales[index].isReserved = false
    }
    await AssetInventory.release(reservedLocale: reservedLocale)
    SpeechModelVerificationCache.invalidate(for: Locale(identifier: item.identifier))
  }

  public func clearDownloadError() {
    downloadError = nil
  }

  public func refreshMenuLocales() async -> [LocaleItem] {
    let reserved = await AssetInventory.reservedLocales
    return reserved.map { locale in
      let key = SpeechLocale.normalizationKey(locale)
      return makeLocaleItem(from: locale, normalizedKey: key, isReserved: true)
    }.sorted { $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey) == .orderedAscending }
  }

  /// Canonical stale-selection correction: returns a replacement identifier
  /// when `currentSelection` matches no item (normalized match wins, then
  /// ja-JP, then the first item), or nil when the selection is already valid.
  public func correctSelection(currentSelection: String, items: [LocaleItem]) -> String? {
    guard !items.isEmpty else { return nil }
    let allIdentifiers = Set(items.map(\.identifier))
    if allIdentifiers.contains(currentSelection) {
      return nil
    }
    if let match = findNormalizedMatch(for: currentSelection, in: items) {
      return match.identifier
    }
    if let match = findNormalizedMatch(for: "ja-JP", in: items) {
      return match.identifier
    }
    return items[0].identifier
  }

  public func findNormalizedMatch(for identifier: String, in items: [LocaleItem]) -> LocaleItem? {
    let sourceKey = SpeechLocale.normalizationKey(identifier)
    return items.first { $0.normalizedKey == sourceKey }
  }

  private func makeLocaleItem(from locale: Locale, normalizedKey: String, isReserved: Bool)
    -> LocaleItem
  {
    let identifier = locale.identifier
    let displayName = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    return LocaleItem(
      identifier: identifier,
      displayName: displayName,
      sortKey: displayName,
      normalizedKey: normalizedKey,
      isReserved: isReserved
    )
  }

  private func performModelDownload(for identifier: String) async throws -> Bool {
    let localeKey = SpeechLocale.normalizationKey(identifier)
    let locale = Locale(identifier: identifier)
    let transcriber = DictationTranscriber(
      locale: locale, preset: SpeechAnalyzerEngine.defaultPreset)

    guard
      let request = try await AssetInventory.assetInstallationRequest(
        supporting: [transcriber]
      )
    else {
      // nil = already installed
      SpeechModelVerificationCache.markVerified(localeKey: localeKey)
      return false
    }

    try await request.downloadAndInstall()
    SpeechModelVerificationCache.markVerified(localeKey: localeKey)
    return true
  }
}
