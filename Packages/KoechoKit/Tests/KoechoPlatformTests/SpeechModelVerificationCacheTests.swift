import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct SpeechModelVerificationCacheTests {
  @Test func markVerifiedStoresLocaleKeyForSession() {
    let locale = Locale(identifier: "en-US")
    let key = SpeechLocale.normalizationKey(locale)
    SpeechModelVerificationCache.invalidate(for: locale)

    #expect(!SpeechModelVerificationCache.isVerified(localeKey: key))

    SpeechModelVerificationCache.markVerified(localeKey: key)

    #expect(SpeechModelVerificationCache.isVerified(localeKey: key))
    SpeechModelVerificationCache.invalidate(for: locale)
  }

  @Test func invalidateRemovesOnlyMatchingNormalizedLocale() {
    let english = Locale(identifier: "en-US")
    let japanese = Locale(identifier: "ja-JP")
    let englishKey = SpeechLocale.normalizationKey(english)
    let japaneseKey = SpeechLocale.normalizationKey(japanese)
    SpeechModelVerificationCache.invalidate(for: english)
    SpeechModelVerificationCache.invalidate(for: japanese)

    SpeechModelVerificationCache.markVerified(localeKey: englishKey)
    SpeechModelVerificationCache.markVerified(localeKey: japaneseKey)

    SpeechModelVerificationCache.invalidate(for: english)

    #expect(!SpeechModelVerificationCache.isVerified(localeKey: englishKey))
    #expect(SpeechModelVerificationCache.isVerified(localeKey: japaneseKey))
    SpeechModelVerificationCache.invalidate(for: japanese)
  }

  @Test func invalidateUsesNormalizedLocaleKey() {
    let hyphenated = Locale(identifier: "en-US")
    let underscoredKey = SpeechLocale.normalizationKey("en_US")
    SpeechModelVerificationCache.invalidate(for: hyphenated)

    SpeechModelVerificationCache.markVerified(localeKey: underscoredKey)
    SpeechModelVerificationCache.invalidate(for: hyphenated)

    #expect(!SpeechModelVerificationCache.isVerified(localeKey: underscoredKey))
  }
}
