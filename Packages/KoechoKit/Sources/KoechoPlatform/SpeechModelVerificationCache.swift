import Foundation

/// Session-scoped cache of locales whose SpeechAnalyzer model has been
/// verified as installed. Keys are `SpeechLocale.normalizationKey` values.
///
/// Shared static storage because both `SpeechAnalyzerEngine` and the
/// throwaway `SpeechAnalyzerLocaleManager` instances consult it.
@MainActor
enum SpeechModelVerificationCache {
  private static var verifiedLocaleKeys: Set<String> = []

  /// Check if a locale's model has been verified this session.
  static func isVerified(localeKey: String) -> Bool {
    verifiedLocaleKeys.contains(localeKey)
  }

  /// Mark a locale's model as verified for this session.
  static func markVerified(localeKey: String) {
    verifiedLocaleKeys.insert(localeKey)
  }

  /// Invalidate the cache for a locale (e.g. after releasing a model).
  static func invalidate(for locale: Locale) {
    verifiedLocaleKeys.remove(SpeechLocale.normalizationKey(locale))
  }
}
