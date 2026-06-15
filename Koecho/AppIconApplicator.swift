import AppKit
import KoechoCore

enum AppIconApplicator {
  @MainActor
  static func apply(_ variant: AppIconVariant) {
    NSApplication.shared.applicationIconImage = image(for: variant)
  }

  private static func image(for variant: AppIconVariant) -> NSImage? {
    switch variant {
    case .current:
      guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
        return nil
      }
      return NSImage(contentsOf: url)
    case .legacy:
      return NSImage(named: "LegacyAppIcon") ?? image(for: .current)
    }
  }
}
