import Foundation
import Observation

public enum AppIconVariant: String, CaseIterable, Sendable {
  case current
  case legacy
}

@MainActor @Observable
public final class AppIconSettings {
  private let defaults: UserDefaults

  private var _selectedAppIcon: AppIconVariant
  public var selectedAppIcon: AppIconVariant {
    get { _selectedAppIcon }
    set {
      _selectedAppIcon = newValue
      save()
    }
  }

  public init(defaults: UserDefaults) {
    self.defaults = defaults

    if let rawValue = defaults.string(forKey: "selectedAppIcon"),
      let variant = AppIconVariant(rawValue: rawValue)
    {
      _selectedAppIcon = variant
    } else {
      _selectedAppIcon = .current
    }

    save()
  }

  private func save() {
    defaults.set(_selectedAppIcon.rawValue, forKey: "selectedAppIcon")
  }
}
