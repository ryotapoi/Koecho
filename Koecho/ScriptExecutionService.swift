import Foundation
import KoechoCore
import KoechoPlatform

@MainActor
final class ScriptExecutionService {
  var textView: (any TextViewOperating)?

  private var activeExecution: (id: UUID, task: Task<ScriptRunnerResult, any Error>?)?

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

    if script.kind == .builtin {
      executeBuiltin(script)
      return
    }

    let id = UUID()
    activeExecution = (id, nil)
    appState.isRunningScript = true
    let suspensionID = voiceCoordinator.suspendInput()
    if let textView, !textView.finalizedString.isEmpty {
      appState.setInputText(textView.finalizedString)
    }
    let originalText = appState.inputText
    let context = makeScriptContext(prompt: appState.promptText + appState.volatilePromptText)
    appState.errorMessage = nil
    defer {
      if activeExecution?.id == id {
        activeExecution = nil
        appState.isRunningScript = false
        appState.promptScript = nil
        appState.promptText = ""
        appState.volatilePromptText = ""
        voiceCoordinator.finishSuspension(suspensionID, resume: true)
      }
    }

    await voiceCoordinator.stopEngine()
    guard activeExecution?.id == id, appState.isInputPanelVisible else { return }
    let execution = startExecution(script, input: originalText, context: context, id: id)
    do {
      let result = try await execution.task.value
      guard activeExecution?.id == id, appState.isInputPanelVisible else { return }
      appState.setInputText(result.output)
      textView?.replaceText(result.output)
      appState.offerScriptUndo(restoring: originalText)
    } catch {
      guard activeExecution?.id == id, appState.isInputPanelVisible else { return }
      appState.setInputText(originalText)
      textView?.replaceText(originalText)
      appState.errorMessage = scriptErrorMessage(for: error, script: script)
    }
  }

  func cancelPrompt() {
    appState.promptScript = nil
    appState.promptText = ""
    appState.volatilePromptText = ""
  }

  func undoLastScript() {
    guard appState.isInputPanelVisible, !isConfirming(), !appState.isRunningScript,
      appState.promptScript == nil,
      let originalText = appState.consumeScriptUndo()
    else { return }
    textView?.clearReplacementPreviews()
    textView?.replaceText(originalText)
    voiceCoordinator.moveVoiceInsertionPoint(toEndOf: originalText)
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
    let execution = startExecution(script, input: text, context: ScriptRunnerContext(prompt: ""))
    defer {
      if activeExecution?.id == execution.id {
        activeExecution = nil
        appState.isRunningScript = false
      }
    }
    do {
      let result = try await execution.task.value
      guard activeExecution?.id == execution.id else { throw CancellationError() }
      return result.output
    } catch {
      guard activeExecution?.id == execution.id else { throw CancellationError() }
      throw error
    }
  }

  func cancelExecution() {
    activeExecution?.task?.cancel()
    activeExecution = nil
    appState.isRunningScript = false
  }

  private func startExecution(
    _ script: Script, input: String, context: ScriptRunnerContext, id: UUID = UUID()
  ) -> (id: UUID, task: Task<ScriptRunnerResult, any Error>) {
    let runner = makeScriptRunner()
    let execution = (id: id, task: Task {
      try await runner.run(scriptPath: script.scriptPath, input: input, context: context)
    })
    activeExecution = execution
    appState.isRunningScript = true
    return execution
  }

  private func executeBuiltin(_ script: Script) {
    guard let builtin = script.builtin else { return }

    // Volatile text is real storage content. Keep it before deriving UTF-16 offsets.
    voiceCoordinator.finalizeVolatileForTextOperation()
    let currentText = textView?.string ?? appState.inputText
    let currentSelection = textView?.selectedRange() ?? NSRange(location: 0, length: 0)
    let result = BuiltinTextOperation.apply(
      to: currentText,
      selection: currentSelection,
      builtin: builtin
    )

    appState.errorMessage = nil
    textView?.replaceText(result.text, selecting: result.selection)
    appState.setInputText(result.text)
    voiceCoordinator.moveVoiceInsertionPoint(
      to: result.selection.location + result.selection.length,
      in: result.text
    )
    appState.offerScriptUndo(restoring: currentText)
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
      String(localized: "Script '\(ScriptPresentation.identification(for: script))' timed out.")
    case ScriptRunnerError.nonZeroExit(let code, let stderr):
      String(
        localized:
          "Script '\(ScriptPresentation.identification(for: script))' failed (exit \(code))\(stderr.isEmpty ? "" : ": \(stderr)")")
    case ScriptRunnerError.emptyOutput:
      String(localized: "Script '\(ScriptPresentation.identification(for: script))' produced empty output.")
    default:
      String(describing: error)
    }
  }
}
