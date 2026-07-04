import Foundation
import Testing

@testable import KoechoCore

struct SpeechLocaleTests {
  @Test func normalizationKeyMatchesHyphenAndUnderscoreIdentifiers() {
    #expect(SpeechLocale.normalizationKey("en-US") == SpeechLocale.normalizationKey("en_US"))
    #expect(SpeechLocale.normalizationKey("zh-Hant-TW") == "zh-Hant-TW")
  }

  @Test func normalizationKeyUsesLanguageScriptAndRegionComponents() {
    let locale = Locale(identifier: "zh-Hant-TW")
    #expect(SpeechLocale.normalizationKey(locale) == "zh-Hant-TW")
  }

  @Test func identifierOverloadMatchesLocaleOverload() {
    #expect(
      SpeechLocale.normalizationKey("ja") == SpeechLocale.normalizationKey(Locale(identifier: "ja"))
    )
  }
}
