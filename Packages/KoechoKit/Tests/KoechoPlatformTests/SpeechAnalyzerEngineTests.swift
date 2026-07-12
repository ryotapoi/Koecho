import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

private let supportsSpeechAnalyzer: Bool = {
  if #available(macOS 26, *) {
    return true
  }
  return false
}()

@MainActor
@Suite(.serialized, .enabled(if: supportsSpeechAnalyzer, "Requires macOS 26 or later"))
struct SpeechAnalyzerEngineTests {
  @Test func initialStateIsIdle() {
    if #available(macOS 26, *) {
      let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
      #expect(engine.state == .idle)
    }
  }

  @Test func startWhenAlreadyListeningIsNoop() {
    if #available(macOS 26, *) {
      let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
      engine.start()
      #expect(engine.state == .listening)
      engine.start()
      #expect(engine.state == .listening)
      engine.cancel()
    }
  }

  @Test func cancelFromIdleRemainsIdle() {
    if #available(macOS 26, *) {
      let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
      engine.cancel()
      #expect(engine.state == .idle)
    }
  }

  @Test func cancelFromListeningGoesToIdle() {
    if #available(macOS 26, *) {
      let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
      engine.start()
      engine.cancel()
      #expect(engine.state == .idle)
    }
  }

  @Test func stopFromIdleRemainsIdle() async {
    if #available(macOS 26, *) {
      let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
      await engine.stop()
      #expect(engine.state == .idle)
    }
  }

  @Test func delegateIsRetained() {
    if #available(macOS 26, *) {
      let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
      let mockDelegate = MockVoiceInputDelegate()
      engine.delegate = mockDelegate
      engine.start()
      engine.cancel()
      #expect(engine.delegate === mockDelegate)
    }
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
