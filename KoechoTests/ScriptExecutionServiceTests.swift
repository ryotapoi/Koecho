import Foundation
import Testing
@testable import Koecho

@MainActor
@Suite struct ScriptExecutionServiceTests {
    private func makeService(
        inputText: String = "",
        isInputPanelVisible: Bool = true,
        scriptTimeout: TimeInterval = 30.0
    ) -> (ScriptExecutionService, AppState, MockTextViewOperating) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = Settings(defaults: defaults)
        settings.script.scriptTimeout = scriptTimeout
        let appState = AppState(settings: settings)
        appState.isInputPanelVisible = isInputPanelVisible
        appState.inputText = inputText

        let service = ScriptExecutionService(
            appState: appState,
            makeScriptRunner: { ScriptRunner(timeout: settings.script.scriptTimeout) },
            setVoiceInsertionPoint: { _ in },
            isConfirming: { false }
        )
        let mockTV = MockTextViewOperating()
        mockTV.string = inputText
        mockTV.finalizedString = inputText
        service.textView = mockTV
        return (service, appState, mockTV)
    }

    // MARK: - Prompt flow

    @Test func executeWithPromptSetsPromptScript() async {
        let (service, appState, _) = makeService(inputText: "hello")
        let script = Script(name: "Test", scriptPath: "cat", requiresPrompt: true)

        await service.execute(script)

        #expect(appState.promptScript == script)
        #expect(appState.isRunningScript == false)
    }

    @Test func executeWithPromptAlreadySetRunsScript() async {
        let (service, appState, _) = makeService(inputText: "hello")
        let script = Script(name: "Test", scriptPath: "cat", requiresPrompt: true)
        appState.promptScript = script

        await service.execute(script)

        // Script ran and completed, prompt cleared
        #expect(appState.promptScript == nil)
        #expect(appState.promptText == "")
    }

    // MARK: - Concurrent execution guard

    @Test func executeSkipsWhenAlreadyRunning() async {
        let (service, appState, _) = makeService(inputText: "hello")
        appState.isRunningScript = true
        let script = Script(name: "Test", scriptPath: "cat")

        await service.execute(script)

        // Should not change inputText (was skipped)
        #expect(appState.inputText == "hello")
    }

    // MARK: - Panel visibility guard

    @Test func executeSkipsWhenNotVisible() async {
        let (service, appState, _) = makeService(
            inputText: "hello",
            isInputPanelVisible: false
        )
        let script = Script(name: "Test", scriptPath: "cat")

        await service.execute(script)

        #expect(appState.inputText == "hello")
    }

    // MARK: - runAutoScript

    @Test func runAutoScriptSuccess() async throws {
        let (service, _, _) = makeService(inputText: "hello")
        let script = Script(name: "Test", scriptPath: "cat")

        let result = try await service.runAutoScript(script, on: "hello world")

        #expect(result == "hello world")
    }

    @Test func runAutoScriptErrorThrows() async {
        let (service, _, _) = makeService(inputText: "hello")
        let script = Script(name: "Test", scriptPath: "exit 1")

        do {
            _ = try await service.runAutoScript(script, on: "hello")
            Issue.record("Expected error to be thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - cycleAutoRunScript

    @Test func cycleAutoRunScriptCycles() {
        let (service, appState, _) = makeService()
        let script1 = Script(name: "S1", scriptPath: "cat")
        let script2 = Script(name: "S2", scriptPath: "cat")
        appState.settings.script.scripts = [script1, script2]

        // nil → first
        service.cycleAutoRunScript()
        #expect(appState.settings.script.autoRunScriptId == script1.id)

        // first → second
        service.cycleAutoRunScript()
        #expect(appState.settings.script.autoRunScriptId == script2.id)

        // second → nil
        service.cycleAutoRunScript()
        #expect(appState.settings.script.autoRunScriptId == nil)
    }

    @Test func cycleAutoRunScriptSkipsPromptScripts() {
        let (service, appState, _) = makeService()
        let script1 = Script(name: "S1", scriptPath: "cat", requiresPrompt: true)
        let script2 = Script(name: "S2", scriptPath: "cat")
        appState.settings.script.scripts = [script1, script2]

        service.cycleAutoRunScript()
        #expect(appState.settings.script.autoRunScriptId == script2.id)
    }

    // MARK: - cancelPrompt

    @Test func cancelPromptResetsState() {
        let (service, appState, _) = makeService()
        let script = Script(name: "Test", scriptPath: "cat", requiresPrompt: true)
        appState.promptScript = script
        appState.promptText = "some prompt"

        service.cancelPrompt()

        #expect(appState.promptScript == nil)
        #expect(appState.promptText == "")
    }
}
