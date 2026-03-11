import Foundation
import KoechoCore
import KoechoPlatform
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

    @Test func runAutoScriptPassesEmptySelection() async throws {
        let scriptPath = try makeScript(
            "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END\""
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let (service, _, mockTV) = makeService(inputText: "hello")
        mockTV.selectedRangeValue = NSRange(location: 3, length: 2)
        let script = Script(name: "Test", scriptPath: scriptPath)

        let result = try await service.runAutoScript(script, on: "hello")

        #expect(result == "sel= start= end=")
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

    // MARK: - Panel selection context

    private func makeScript(_ content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent("koecho-test-\(UUID().uuidString).sh").path
        try ("#!/bin/sh\n" + content).write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    @Test func executePassesPanelSelection() async throws {
        let scriptPath = try makeScript(
            "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END\""
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let (service, appState, mockTV) = makeService(inputText: "hello world")
        mockTV.string = "hello world"
        mockTV.selectedRangeValue = NSRange(location: 6, length: 5)
        let script = Script(name: "Test", scriptPath: scriptPath)

        await service.execute(script)

        #expect(appState.inputText == "sel=world start=6 end=11")
    }

    @Test func executeWithNoSelectionPassesCursorPosition() async throws {
        let scriptPath = try makeScript(
            "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END\""
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let (service, appState, mockTV) = makeService(inputText: "hello")
        mockTV.string = "hello"
        mockTV.selectedRangeValue = NSRange(location: 3, length: 0)
        let script = Script(name: "Test", scriptPath: scriptPath)

        await service.execute(script)

        #expect(appState.inputText == "sel= start=3 end=3")
    }

    @Test func executeWithNilTextViewPassesZeros() async throws {
        let scriptPath = try makeScript(
            "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END\""
        )
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let (service, appState, _) = makeService(inputText: "hello")
        service.textView = nil
        let script = Script(name: "Test", scriptPath: scriptPath)

        await service.execute(script)

        #expect(appState.inputText == "sel= start=0 end=0")
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
