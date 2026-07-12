import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct SpeechModelVerificationCacheTests {
  @Test func markVerifiedStoresLocaleKeyForSession() {
    let cache = SpeechModelVerificationCache()
    let locale = Locale(identifier: "en-US")
    let key = SpeechLocale.normalizationKey(locale)

    #expect(!cache.isVerified(localeKey: key))

    cache.markVerified(localeKey: key)

    #expect(cache.isVerified(localeKey: key))
  }

  @Test func invalidateRemovesOnlyMatchingNormalizedLocale() {
    let cache = SpeechModelVerificationCache()
    let english = Locale(identifier: "en-US")
    let japanese = Locale(identifier: "ja-JP")
    let englishKey = SpeechLocale.normalizationKey(english)
    let japaneseKey = SpeechLocale.normalizationKey(japanese)

    cache.markVerified(localeKey: englishKey)
    cache.markVerified(localeKey: japaneseKey)

    cache.invalidate(for: english)

    #expect(!cache.isVerified(localeKey: englishKey))
    #expect(cache.isVerified(localeKey: japaneseKey))
  }

  @Test func invalidateUsesNormalizedLocaleKey() {
    let cache = SpeechModelVerificationCache()
    let hyphenated = Locale(identifier: "en-US")
    let underscoredKey = SpeechLocale.normalizationKey("en_US")

    cache.markVerified(localeKey: underscoredKey)
    cache.invalidate(for: hyphenated)

    #expect(!cache.isVerified(localeKey: underscoredKey))
  }

  @Test func separateInstancesDoNotShareVerificationState() {
    let first = SpeechModelVerificationCache()
    let second = SpeechModelVerificationCache()
    let key = SpeechLocale.normalizationKey("en_US")

    first.markVerified(localeKey: key)

    #expect(first.isVerified(localeKey: key))
    #expect(!second.isVerified(localeKey: key))
  }
}
