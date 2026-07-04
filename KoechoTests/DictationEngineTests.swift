import AppKit
import KoechoCore
import Testing

@testable import Koecho

@MainActor
@Suite(.serialized)
struct DictationEngineTests {
  private func makeEngine() -> (engine: DictationEngine, sentSelectors: @MainActor () -> [Selector]) {
    var sentSelectors: [Selector] = []
    let engine = DictationEngine { selector in
      sentSelectors.append(selector)
      return true
    }
    return (engine, { sentSelectors })
  }

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
    let (engine, sentSelectors) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    engine.start()
    try? await Task.sleep(for: .milliseconds(400))
    withExtendedLifetime(panel) {}

    #expect(sentSelectors() == [Selector(("startDictation:"))])
    #expect(engine.state == .listening)
  }

  @Test func cancelBeforeDelayPreventsStartDictationAction() async {
    let (engine, sentSelectors) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    engine.start()
    engine.cancel()
    try? await Task.sleep(for: .milliseconds(400))

    #expect(sentSelectors().isEmpty)
    #expect(engine.state == .idle)
  }

  @Test func stopFromListeningTransitions() async {
    let (engine, sentSelectors) = makeEngine()
    let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100))
    engine.configure(panel: panel, textView: nil)

    // Simulate listening state by dispatching the delayed start
    engine.start()
    // Wait for delayed dispatch to fire
    try? await Task.sleep(for: .milliseconds(400))
    withExtendedLifetime(panel) {}

    await engine.stop()
    #expect(sentSelectors() == [Selector(("startDictation:"))])
    #expect(engine.state == .idle)
  }
}
