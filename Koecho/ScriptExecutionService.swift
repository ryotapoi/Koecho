import Foundation
import KoechoCore
import KoechoPlatform

@MainActor
final class ScriptExecutionService {
  var textView: (any TextViewOperating)?

  private let appState: AppState
  private let makeScriptRunner: () -> ScriptRunner
  private let voiceCoordinator: VoiceInputCoordinator
  private let isConfirming: () -> Bool

  init(
    appState: AppState,
    makeScriptRunner: @escaping () -> ScriptRunner,
    voiceCoordinator: VoiceInputCoordinator,
    isConfirming: @escaping () -> Bool
  ) {
    self.appState = appState
    self.makeScriptRunner = makeScriptRunner
    self.voiceCoordinator = voiceCoordinator
    self.isConfirming = isConfirming
  }

  func execute(_ script: Script) async {
    guard appState.isInputPanelVisible,
      !isConfirming(),
      !appState.isRunningScript,
      appState.promptScript == nil || appState.promptScript == script
    else { return }

    if script.requiresPrompt && appState.promptScript == nil {
      appState.errorMessage = nil
      appState.promptScript = script
      return
    }

    textView?.clearVolatileText()
    if let textView {
      let tvString = textView.finalizedString
      if !tvString.isEmpty {
        appState.setInputText(tvString)
      }
    }

    let originalText = appState.inputText
    appState.isRunningScript = true
    defer {
      appState.isRunningScript = false
      appState.promptScript = nil
      appState.promptText = ""
      appState.volatilePromptText = ""
    }

    appState.errorMessage = nil

    let context = makeScriptContext(prompt: appState.promptText + appState.volatilePromptText)

    let runner = makeScriptRunner()
    do {
      let result = try await runner.run(
        scriptPath: script.scriptPath,
        input: appState.inputText,
        context: context
      )
      guard appState.isInputPanelVisible else { return }
      appState.setInputText(result.output)
      voiceCoordinator.moveVoiceInsertionPoint(toEndOf: result.output)
    } catch {
      guard appState.isInputPanelVisible else { return }
      appState.setInputText(originalText)
      appState.errorMessage = scriptErrorMessage(for: error, script: script)
    }
  }

  func cancelPrompt() {
    appState.promptScript = nil
    appState.promptText = ""
    appState.volatilePromptText = ""
  }

  func cycleAutoRunScript() {
    let eligible = appState.settings.script.eligibleAutoRunScripts
    guard !eligible.isEmpty else {
      appState.settings.script.autoRunScriptId = nil
      return
    }
    if let currentId = appState.settings.script.autoRunScriptId,
      let idx = eligible.firstIndex(where: { $0.id == currentId })
    {
      let next = idx + 1
      appState.settings.script.autoRunScriptId = next < eligible.count ? eligible[next].id : nil
    } else {
      appState.settings.script.autoRunScriptId = eligible[0].id
    }
  }

  func runAutoScript(_ script: Script, on text: String) async throws -> String {
    let context = ScriptRunnerContext(prompt: "")
    let runner = makeScriptRunner()
    let result = try await runner.run(
      scriptPath: script.scriptPath,
      input: text,
      context: context
    )
    return result.output
  }

  private func makeScriptContext(prompt: String) -> ScriptRunnerContext {
    let range = textView?.selectedRange() ?? NSRange(location: 0, length: 0)
    let selection: String
    if let textView, range.length > 0,
      range.location + range.length <= (textView.string as NSString).length
    {
      selection = (textView.string as NSString).substring(with: range)
    } else {
      selection = ""
    }
    return ScriptRunnerContext(
      selection: selection,
      selectionStart: String(range.location),
      selectionEnd: String(range.location + range.length),
      prompt: prompt
    )
  }

  func scriptErrorMessage(for error: any Error, script: Script) -> String {
    switch error {
    case ScriptRunnerError.emptyScript:
      String(localized: "Script command is empty.")
    case ScriptRunnerError.timeout:
      String(localized: "Script '\(script.name)' timed out.")
    case ScriptRunnerError.nonZeroExit(let code, let stderr):
      String(
        localized:
          "Script '\(script.name)' failed (exit \(code))\(stderr.isEmpty ? "" : ": \(stderr)")")
    case ScriptRunnerError.emptyOutput:
      String(localized: "Script '\(script.name)' produced empty output.")
    default:
      String(describing: error)
    }
  }
}
