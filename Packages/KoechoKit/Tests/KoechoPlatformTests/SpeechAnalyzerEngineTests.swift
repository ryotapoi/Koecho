import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
@Suite(.serialized)
struct SpeechAnalyzerEngineTests {
  @Test func initialStateIsIdle() {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    #expect(engine.state == .idle)
  }

  @Test func startWhenAlreadyListeningIsNoop() {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    engine.start()
    #expect(engine.state == .listening)
    engine.start()
    #expect(engine.state == .listening)
    engine.cancel()
  }

  @Test func cancelFromIdleRemainsIdle() {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    engine.cancel()
    #expect(engine.state == .idle)
  }

  @Test func cancelFromListeningGoesToIdle() {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    engine.start()
    engine.cancel()
    #expect(engine.state == .idle)
  }

  @Test func stopFromIdleRemainsIdle() async {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    await engine.stop()
    #expect(engine.state == .idle)
  }

  @Test func delegateIsRetained() {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    let mockDelegate = MockVoiceInputDelegate()
    engine.delegate = mockDelegate
    engine.start()
    engine.cancel()
    #expect(engine.delegate === mockDelegate)
  }
}

@MainActor
private final class MockVoiceInputDelegate: VoiceInputDelegate {
  var finalizedTexts: [String] = []
  var volatileTexts: [String] = []
  var errors: [VoiceInputEngineError] = []
  var statuses: [VoiceInputEngineStatus?] = []

  func voiceInput(didFinalize text: String) { finalizedTexts.append(text) }
  func voiceInput(didUpdateVolatile text: String) { volatileTexts.append(text) }
  func voiceInput(didEncounterError error: VoiceInputEngineError) { errors.append(error) }
  func voiceInput(didUpdateStatus status: VoiceInputEngineStatus?) { statuses.append(status) }
}
