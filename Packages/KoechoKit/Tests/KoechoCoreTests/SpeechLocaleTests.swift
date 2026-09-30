import Testing

@testable import KoechoCore

struct SpeechLocaleTests {
  @Test func normalizationKeyMatchesHyphenAndUnderscoreIdentifiers() {
    #expect(SpeechLocale.normalizationKey("en-US") == SpeechLocale.normalizationKey("en_US"))
    #expect(SpeechLocale.normalizationKey("zh-Hant-TW") == "zh-Hant-TW")
  }

}
