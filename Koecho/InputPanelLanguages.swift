import Foundation
import KoechoPlatform
import Observation

@MainActor @Observable
final class InputPanelLanguages {
  var locales: [LocaleItem] = []

  var hasMultipleLanguages: Bool { locales.count > 1 }

  static func displayCode(for identifier: String) -> String {
    let code = identifier.replacingOccurrences(of: "_", with: "-")
    // Cantonese is the only supported code longer than five characters.
    return code == "yue-CN" ? "yueCN" : code
  }
}
