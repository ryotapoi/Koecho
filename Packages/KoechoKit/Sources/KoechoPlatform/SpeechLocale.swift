import Foundation

/// Locale-key utilities for SpeechAnalyzer asset matching.
///
/// SpeechAnalyzer APIs report locales in differing identifier string forms
/// (`-` vs `_`, with or without script), so comparisons go through a
/// normalized `languageCode-script-region` key instead of raw identifiers.
public enum SpeechLocale {
  /// Normalized key for locale-based lookups (languageCode-script-region).
  public static func normalizationKey(_ locale: Locale) -> String {
    let lang = locale.language.languageCode?.identifier ?? ""
    let script = locale.language.script?.identifier ?? ""
    let region = locale.language.region?.identifier ?? ""
    return "\(lang)-\(script)-\(region)"
  }

  /// Convenience overload accepting a locale identifier string.
  public static func normalizationKey(_ identifier: String) -> String {
    normalizationKey(Locale(identifier: identifier))
  }
}
