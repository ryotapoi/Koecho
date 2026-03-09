import Foundation

@MainActor
final class ScriptExecutionService {
    var textView: (any TextViewOperating)?

    private let appState: AppState
    private let makeScriptRunner: () -> ScriptRunner
    private let setVoiceInsertionPoint: (Int) -> Void
    private let isConfirming: () -> Bool

    init(
        appState: AppState,
        makeScriptRunner: @escaping () -> ScriptRunner,
        setVoiceInsertionPoint: @escaping (Int) -> Void,
        isConfirming: @escaping () -> Bool
    ) {
        self.appState = appState
        self.makeScriptRunner = makeScriptRunner
        self.setVoiceInsertionPoint = setVoiceInsertionPoint
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
                appState.inputText = tvString
            }
        }

        let originalText = appState.inputText
        appState.isRunningScript = true
        defer {
            appState.isRunningScript = false
            appState.promptScript = nil
            appState.promptText = ""
        }

        appState.errorMessage = nil

        let context = ScriptRunnerContext(
            selection: appState.selectedText,
            selectionStart: appState.selectionStart,
            selectionEnd: appState.selectionEnd,
            prompt: appState.promptText
        )

        let runner = makeScriptRunner()
        do {
            let result = try await runner.run(
                scriptPath: script.scriptPath,
                input: appState.inputText,
                context: context
            )
            guard appState.isInputPanelVisible else { return }
            appState.inputText = result.output
            setVoiceInsertionPoint((result.output as NSString).length)
        } catch {
            guard appState.isInputPanelVisible else { return }
            appState.inputText = originalText
            appState.errorMessage = scriptErrorMessage(for: error, script: script)
        }
    }

    func cancelPrompt() {
        appState.promptScript = nil
        appState.promptText = ""
    }

    func cycleAutoRunScript() {
        let eligible = appState.settings.scripts.filter { !$0.requiresPrompt }
        guard !eligible.isEmpty else {
            appState.settings.autoRunScriptId = nil
            return
        }
        if let currentId = appState.settings.autoRunScriptId,
           let idx = eligible.firstIndex(where: { $0.id == currentId }) {
            let next = idx + 1
            appState.settings.autoRunScriptId = next < eligible.count ? eligible[next].id : nil
        } else {
            appState.settings.autoRunScriptId = eligible[0].id
        }
    }

    func runAutoScript(_ script: Script, on text: String) async throws -> String {
        let context = ScriptRunnerContext(
            selection: appState.selectedText,
            selectionStart: appState.selectionStart,
            selectionEnd: appState.selectionEnd,
            prompt: ""
        )
        let runner = makeScriptRunner()
        let result = try await runner.run(
            scriptPath: script.scriptPath,
            input: text,
            context: context
        )
        return result.output
    }

    func scriptErrorMessage(for error: any Error, script: Script) -> String {
        switch error {
        case ScriptRunnerError.emptyScript:
            "Script command is empty."
        case ScriptRunnerError.timeout:
            "Script '\(script.name)' timed out."
        case ScriptRunnerError.nonZeroExit(let code, let stderr):
            "Script '\(script.name)' failed (exit \(code))\(stderr.isEmpty ? "" : ": \(stderr)")"
        case ScriptRunnerError.emptyOutput:
            "Script '\(script.name)' produced empty output."
        default:
            String(describing: error)
        }
    }
}
