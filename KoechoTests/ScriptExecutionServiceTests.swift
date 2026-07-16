import AppKit
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
    scriptTimeout: TimeInterval = 30.0,
    makeEngine: @escaping () -> any VoiceInputEngine = { MockVoiceInputEngine() }
  ) -> (ScriptExecutionService, AppState, MockTextViewOperating, VoiceInputCoordinator) {
    let appState = makeTestAppState()
    appState.settings.script.scriptTimeout = scriptTimeout
    appState.isInputPanelVisible = isInputPanelVisible
    appState.setInputText(inputText)

    let coordinator = makeTestVoiceCoordinator(appState: appState, makeEngine: makeEngine)
    let service = ScriptExecutionService(
      appState: appState,
      makeScriptRunner: { ScriptRunner(timeout: appState.settings.script.scriptTimeout) },
      voiceCoordinator: coordinator,
      isConfirming: { false }
    )
    let mockTV = MockTextViewOperating()
    mockTV.string = inputText
    mockTV.finalizedString = inputText
    coordinator.textView = mockTV
    service.textView = mockTV
    return (service, appState, mockTV, coordinator)
  }

  // MARK: - Prompt flow

  @Test func executeWithPromptSetsPromptScript() async {
    let (service, appState, _, _) = makeService(inputText: "hello")
    let script = Script(name: "Test", scriptPath: "cat", requiresPrompt: true)

    await service.execute(script)

    #expect(appState.promptScript == script)
    #expect(appState.isRunningScript == false)
  }

  @Test func executeWithPromptAlreadySetRunsScript() async {
    let (service, appState, _, _) = makeService(inputText: "hello")
    let script = Script(name: "Test", scriptPath: "cat", requiresPrompt: true)
    appState.promptScript = script
    appState.volatilePromptText = "volatile"

    await service.execute(script)

    // Script ran and completed, prompt cleared
    #expect(appState.promptScript == nil)
    #expect(appState.promptText == "")
    #expect(appState.volatilePromptText == "")
  }

  @Test func executeWithPromptIncludesVolatilePromptText() async throws {
    let scriptPath = try makeScript("echo \"$KOECHO_PROMPT\"")
    defer { try? FileManager.default.removeItem(atPath: scriptPath) }

    let (service, appState, _, _) = makeService(inputText: "hello")
    let script = Script(name: "Test", scriptPath: scriptPath, requiresPrompt: true)
    appState.promptScript = script
    appState.promptText = "make "
    appState.volatilePromptText = "short"

    await service.execute(script)

    #expect(appState.inputText == "make short")
    #expect(appState.volatilePromptText == "")
  }

  // MARK: - Voice insertion point

  @Test func executeBuiltinFinalizesVolatileAndSynchronizesTextSelectionAndVoiceInsertion() async {
    let (service, appState, textView, coordinator) = makeService(inputText: "stale")
    textView.string = "one\ntwo"
    textView.finalizedString = "one"
    textView.volatileRange = NSRange(location: 3, length: 4)
    textView.selectedRangeValue = NSRange(location: 0, length: 3)
    let builtin = Script(
      id: UUID(),
      builtin: BuiltinScript(feature: .increaseIndent, indentationWidth: .two)!
    )

    await service.execute(builtin)

    #expect(textView.finalizeVolatileTextCallCount == 1)
    #expect(textView.clearVolatileTextCallCount == 0)
    #expect(textView.replaceTextSelectingCalls.count == 1)
    #expect(textView.replaceTextSelectingCalls[0].text == "  one\ntwo")
    #expect(textView.replaceTextSelectingCalls[0].range == NSRange(location: 0, length: 5))
    #expect(appState.inputText == "  one\ntwo")
    #expect(coordinator.voiceInsertionPoint == 5)
    #expect(appState.errorMessage == nil)
  }

  @Test func executeBuiltinSuppressesReplayedVolatileFinalization() async {
    let engine = MockRestartableVoiceInputEngine()
    let (service, appState, textView, coordinator) = makeService(
      inputText: "one",
      makeEngine: { engine }
    )
    textView.string = "one two"
    textView.finalizedString = "one"
    textView.volatileRange = NSRange(location: 3, length: 4)
    textView.selectedRangeValue = NSRange(location: 0, length: 7)
    let builtin = Script(
      id: UUID(),
      builtin: BuiltinScript(feature: .blockQuote)!
    )

    await service.execute(builtin)
    await coordinator.restartTranscriberTask?.value
    coordinator.voiceInput(didFinalize: " two")

    #expect(engine.restartTranscriberCallCount == 1)
    #expect(appState.inputText == "> one two")
    #expect(textView.insertFinalizedTextCalls.isEmpty)
  }

  @Test func executeBuiltinDoesNotUseCustomRunnerFailurePath() async {
    let (service, appState, _, _) = makeService(inputText: "one")
    let builtin = Script(
      id: UUID(),
      builtin: BuiltinScript(feature: .blockQuote)!
    )

    appState.errorMessage = "Previous script failed"
    await service.execute(builtin)

    #expect(appState.inputText == "> one")
    #expect(appState.errorMessage == nil)
  }

  @Test func executeMovesVoiceInsertionPointToEndOfOutput() async {
    let (service, appState, _, coordinator) = makeService(inputText: "hello")
    let script = Script(name: "Test", scriptPath: "cat")

    await service.execute(script)

    #expect(appState.inputText == "hello")
    #expect(coordinator.voiceInsertionPoint == 5)
  }

  // MARK: - Concurrent execution guard

  @Test func executeSkipsWhenAlreadyRunning() async {
    let (service, appState, _, _) = makeService(inputText: "hello")
    appState.isRunningScript = true
    let script = Script(name: "Test", scriptPath: "cat")

    await service.execute(script)

    // Should not change inputText (was skipped)
    #expect(appState.inputText == "hello")
  }

  // MARK: - Panel visibility guard

  @Test func executeSkipsWhenNotVisible() async {
    let (service, appState, _, _) = makeService(
      inputText: "hello",
      isInputPanelVisible: false
    )
    let script = Script(name: "Test", scriptPath: "cat")

    await service.execute(script)

    #expect(appState.inputText == "hello")
  }

  // MARK: - runAutoScript

  @Test func runAutoScriptSuccess() async throws {
    let (service, _, _, _) = makeService(inputText: "hello")
    let script = Script(name: "Test", scriptPath: "cat")

    let result = try await service.runAutoScript(script, on: "hello world")

    #expect(result == "hello world")
  }

  @Test func runAutoScriptPassesEmptySelection() async throws {
    let scriptPath = try makeScript(
      "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END\""
    )
    defer { try? FileManager.default.removeItem(atPath: scriptPath) }

    let (service, _, mockTV, _) = makeService(inputText: "hello")
    mockTV.selectedRangeValue = NSRange(location: 3, length: 2)
    let script = Script(name: "Test", scriptPath: scriptPath)

    let result = try await service.runAutoScript(script, on: "hello")

    #expect(result == "sel= start= end=")
  }

  @Test func runAutoScriptErrorThrows() async {
    let (service, _, _, _) = makeService(inputText: "hello")
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
    let (service, appState, _, _) = makeService()
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
    let (service, appState, _, _) = makeService()
    let script1 = Script(name: "S1", scriptPath: "cat", requiresPrompt: true)
    let script2 = Script(name: "S2", scriptPath: "cat")
    appState.settings.script.scripts = [script1, script2]

    service.cycleAutoRunScript()
    #expect(appState.settings.script.autoRunScriptId == script2.id)
  }

  // MARK: - Panel selection context

  @Test func executePassesPanelSelection() async throws {
    let scriptPath = try makeScript(
      "echo \"sel=$KOECHO_SELECTION start=$KOECHO_SELECTION_START end=$KOECHO_SELECTION_END\""
    )
    defer { try? FileManager.default.removeItem(atPath: scriptPath) }

    let (service, appState, mockTV, _) = makeService(inputText: "hello world")
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

    let (service, appState, mockTV, _) = makeService(inputText: "hello")
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

    let (service, appState, _, _) = makeService(inputText: "hello")
    service.textView = nil
    let script = Script(name: "Test", scriptPath: scriptPath)

    await service.execute(script)

    #expect(appState.inputText == "sel= start=0 end=0")
  }

  // MARK: - cancelPrompt

  @Test func cancelPromptResetsState() {
    let (service, appState, _, _) = makeService()
    let script = Script(name: "Test", scriptPath: "cat", requiresPrompt: true)
    appState.promptScript = script
    appState.promptText = "some prompt"
    appState.volatilePromptText = "volatile"

    service.cancelPrompt()

    #expect(appState.promptScript == nil)
    #expect(appState.promptText == "")
    #expect(appState.volatilePromptText == "")
  }
}
