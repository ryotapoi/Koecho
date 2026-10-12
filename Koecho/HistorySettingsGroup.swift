import KoechoCore
import SwiftUI

struct HistorySettingsGroup: View {
  @Bindable var settings: HistorySettings

  var body: some View {
    Form {
      Section("History") {
        Toggle("Enable History", isOn: $settings.isHistoryEnabled)
        TextField("Max entries", value: $settings.historyMaxCount, format: .number)
        TextField("Retention days", value: $settings.historyRetentionDays, format: .number)
      }
    }
    .formStyle(.grouped)
    .contentMargins(.bottom, 0, for: .scrollContent)
    .scrollDisabled(true)
    .fixedSize(horizontal: false, vertical: true)
  }
}
