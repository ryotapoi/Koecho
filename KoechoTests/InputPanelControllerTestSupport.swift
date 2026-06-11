import AppKit
import Foundation
import KoechoCore
import KoechoPlatform

@testable import Koecho

/// Holds an InputPanelController and its collaborators for one test,
/// and closes the panel when the test finishes.
@MainActor
final class TestContext {
  let controller: InputPanelController
  let appState: AppState
  let paster: MockPaster
  let historyStore: HistoryStore
  let ducker: MockVolumeDucker

  init(
    controller: InputPanelController,
    appState: AppState,
    paster: MockPaster,
    historyStore: HistoryStore,
    ducker: MockVolumeDucker
  ) {
    self.controller = controller
    self.appState = appState
    self.paster = paster
    self.historyStore = historyStore
    self.ducker = ducker
  }

  isolated deinit {
    controller.panel.orderOut(nil)
  }
}

@MainActor
func makeController(
  paster: MockPaster? = nil,
  selectedTextReader: (any SelectedTextReading)? = nil,
  makeScriptRunner: (() -> ScriptRunner)? = nil,
  ducker: MockVolumeDucker? = nil
) -> TestContext {
  let p = paster ?? MockPaster()
  let d = ducker ?? MockVolumeDucker()
  let appState = makeTestAppState()
  // Default to a mock returning nil so tests don't pick up whatever text is
  // actually selected on the machine running them.
  let reader: any SelectedTextReading = selectedTextReader ?? MockSelectedTextReader()
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("koecho-test-\(UUID().uuidString)")
  let historyStore = HistoryStore(directoryURL: dir)
  let controller = InputPanelController(
    appState: appState,
    selectedTextReader: reader,
    paster: p,
    makeScriptRunner: makeScriptRunner ?? {
      ScriptRunner(timeout: appState.settings.script.scriptTimeout)
    },
    makeEngine: { MockVoiceInputEngine() },
    historyStore: historyStore,
    ducker: d
  )
  return TestContext(
    controller: controller,
    appState: appState,
    paster: p,
    historyStore: historyStore,
    ducker: d
  )
}
