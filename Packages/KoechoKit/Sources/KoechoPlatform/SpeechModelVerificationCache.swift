import Foundation
import KoechoCore

/// Session-scoped cache of locales whose SpeechAnalyzer model has been
/// verified as installed. Keys are `SpeechLocale.normalizationKey` values.
///
/// The shared instance is used because both `SpeechAnalyzerEngine` and the
/// throwaway `SpeechAnalyzerLocaleManager` instances consult it. The cache
/// avoids repeated model checks after `assetInstallationRequest` has verified
/// the locale, because released models can still appear in `installedLocales`
/// while requiring a fresh reservation/download before use.
@MainActor
final class SpeechModelVerificationCache {
  static let shared = SpeechModelVerificationCache()

  private var verifiedLocaleKeys: Set<String> = []

  /// Check if a locale's model has been verified this session.
  func isVerified(localeKey: String) -> Bool {
    verifiedLocaleKeys.contains(localeKey)
  }

  /// Mark a locale's model as verified for this session.
  func markVerified(localeKey: String) {
    verifiedLocaleKeys.insert(localeKey)
  }

  /// Invalidate the cache for a locale (e.g. after releasing a model).
  func invalidate(for locale: Locale) {
    verifiedLocaleKeys.remove(SpeechLocale.normalizationKey(locale))
  }
}
