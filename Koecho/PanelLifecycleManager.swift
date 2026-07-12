import AppKit
import KoechoCore
import KoechoPlatform

@MainActor
final class PanelLifecycleManager {
  private let appState: AppState
  private let selectedTextReader: any SelectedTextReading
  private let ducker: any VolumeDucking
  private let panel: InputPanel

  init(
    appState: AppState,
    selectedTextReader: any SelectedTextReading,
    ducker: any VolumeDucking,
    panel: InputPanel
  ) {
    self.appState = appState
    self.selectedTextReader = selectedTextReader
    self.ducker = ducker
    self.panel = panel
  }

  func show(duckVolume: Bool = true) {
    appState.isRunningScript = false
    appState.frontmostApplication = NSWorkspace.shared.frontmostApplication

    if let app = appState.frontmostApplication,
      let result = selectedTextReader.read(from: app.processIdentifier)
    {
      appState.setInputText(result.text)
    } else {
      appState.setInputText("")
    }
    appState.errorMessage = nil
    appState.isInputPanelVisible = true
    if duckVolume {
      ducker.duck()
    }
    panel.makeKeyAndOrderFront(nil)
  }

  func clearState() {
    ducker.restore()
    appState.setInputText("")
    appState.isInputPanelVisible = false
    appState.frontmostApplication = nil
    appState.errorMessage = nil
    appState.voiceEngineStatus = nil
    appState.isRunningScript = false
    appState.promptScript = nil
    appState.promptText = ""
    appState.volatilePromptText = ""
    appState.pendingReplacementPattern = nil
  }

  func hide() {
    panel.orderOut(nil)
  }
}
