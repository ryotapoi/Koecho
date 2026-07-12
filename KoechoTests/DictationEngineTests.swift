import AppKit
import KoechoCore
import Testing

@testable import Koecho

@MainActor
@Suite(.serialized)
struct DictationEngineTests {
  private final class StartActionRecorder {
    private(set) var selectors: [Selector] = []
    private var actionContinuation: CheckedContinuation<Void, Never>?

    func send(_ selector: Selector) -> Bool {
      selectors.append(selector)
      actionContinuation?.resume()
      actionContinuation = nil
      return true
    }

    func waitForAction() async {
      guard selectors.isEmpty else { return }
      await withCheckedContinuation { continuation in
        actionContinuation = continuation
      }
    }
  }

  private final class FirstStartDelay {
    private var firstInvocationHasStarted = false
    private var firstInvocationContinuation: CheckedContinuation<Void, Never>?

    func wait() async throws {
      if !firstInvocationHasStarted {
        firstInvocationHasStarted = true
        firstInvocationContinuation?.resume()
        firstInvocationContinuation = nil
        try await Task.sleep(for: .seconds(60))
      }
    }

    func waitForFirstInvocation() async {
      guard !firstInvocationHasStarted else { return }
      await withCheckedContinuation { continuation in
        firstInvocationContinuation = continuation
      }
    }
  }

  private enum StartDelayError: Error {
    case failed
  }

  private final class FailingFirstStartDelay {
    private var invocationCount = 0
    private var firstInvocationContinuation: CheckedContinuation<Void, Never>?

    func wait() async throws {
      invocationCount += 1
      if invocationCount == 1 {
        firstInvocationContinuation?.resume()
        firstInvocationContinuation = nil
        throw StartDelayError.failed
      }
    }

    func waitForFirstInvocation() async {
      guard invocationCount == 0 else { return }
      await withCheckedContinuation { continuation in
        firstInvocationContinuation = continuation
      }
    }
  }

  private final class RetryTaskClearRecorder {
    private var clearCount = 0
    private var clearContinuation: CheckedContinuation<Void, Never>?

    func recordClear() {
      clearCount += 1
      clearContinuation?.resume()
      clearContinuation = nil
    }

    func waitForClear() async {
      guard clearCount == 0 else { return }
      await withCheckedContinuation { continuation in
        clearContinuation = continuation
      }
    }
  }

  private func makeEngine(
    startDelay: @escaping DictationEngine.StartDelay = {},
    retryTaskClearObserver: @escaping DictationEngine.RetryTaskClearObserver = {}
  ) -> (engine: DictationEngine, actions: StartActionRecorder) {
    let actions = StartActionRecorder()
    let engine = DictationEngine(
      startDictationActionSender: actions.send,
      startDelay: startDelay,
      retryTaskClearObserver: retryTaskClearObserver
    )
    return (engine, actions)
  }

  private let startSelector = Selector(("startDictation:"))

  @Test func initialStateIsIdle() {
    let engine = DictationEngine()
    #expect(engine.state == .idle)
  }

  @Test func startWithoutConfigureIsNoop() {
    let engine = DictationEngine()
    // No panel configured, start should be a no-op
    engine.start()
    // State remains idle since panel is nil
    #expect(engine.state == .idle)
  }

  @Test func cancelFromIdleRemainsIdle() {
    let engine = DictationEngine()
    engine.cancel()
    #expect(engine.state == .idle)
  }

  @Test func stopFromIdleTransitionsToStoppingThenIdle() async {
    let engine = DictationEngine()
    await engine.stop()
    #expect(engine.state == .idle)
  }

  @Test func cancelResetsState() {
    let (engine, _) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)
    engine.start()
    // Cancel should reset state to idle
    engine.cancel()
    #expect(engine.state == .idle)
  }

  @Test func restartResetsAndStarts() {
    let (engine, _) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)
    // restart should work even if state isn't idle
    engine.restart()
    #expect(engine.state == .idle || engine.state == .listening)
    engine.cancel()
  }

  @Test func doubleStartIsNoop() {
    let (engine, _) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)
    engine.start()
    // Second start while retryTask is pending should be no-op
    engine.start()
    // Should not crash or duplicate work
    engine.cancel()
  }

  @Test func startSendsInjectedStartDictationActionAfterDelay() async {
    let (engine, actions) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    engine.start()
    await actions.waitForAction()
    withExtendedLifetime(panel) {}

    #expect(actions.selectors == [startSelector])
    #expect(engine.state == .listening)
  }

  @Test func cancelBeforeDelayPreventsStartDictationAction() async {
    let delay = FirstStartDelay()
    let (engine, actions) = makeEngine(startDelay: delay.wait)
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    engine.start()
    await delay.waitForFirstInvocation()
    engine.cancel()
    withExtendedLifetime(panel) {}

    #expect(actions.selectors.isEmpty)
    #expect(engine.state == .idle)
  }

  @Test func restartCancelsPendingStartBeforeStartingAgain() async {
    let delay = FirstStartDelay()
    let (engine, actions) = makeEngine(startDelay: delay.wait)
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    engine.start()
    await delay.waitForFirstInvocation()
    engine.restart()
    await actions.waitForAction()
    withExtendedLifetime(panel) {}

    #expect(actions.selectors == [startSelector])
    #expect(engine.state == .listening)
  }

  @Test func startRetriesAfterNonCancellationDelayFailure() async {
    let delay = FailingFirstStartDelay()
    let retryTaskClearRecorder = RetryTaskClearRecorder()
    let (engine, actions) = makeEngine(
      startDelay: delay.wait,
      retryTaskClearObserver: retryTaskClearRecorder.recordClear
    )
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    engine.start()
    await delay.waitForFirstInvocation()
    await retryTaskClearRecorder.waitForClear()
    engine.start()
    await actions.waitForAction()
    withExtendedLifetime(panel) {}

    #expect(actions.selectors == [startSelector])
    #expect(engine.state == .listening)
  }

  @Test func stopFromListeningTransitions() async {
    let (engine, actions) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    // Simulate listening state by dispatching the delayed start
    engine.start()
    await actions.waitForAction()
    withExtendedLifetime(panel) {}

    await engine.stop()
    #expect(actions.selectors == [startSelector])
    #expect(engine.state == .idle)
  }
}
