import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
@Suite(.serialized)
struct SpeechAnalyzerEngineTests {
  @Test func idleCancelAndStopRemainIdle() async {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    #expect(engine.state == .idle)
    engine.cancel()
    #expect(engine.state == .idle)
    await engine.stop()
    #expect(engine.state == .idle)
  }

  @Test func cancelFromListeningGoesToIdle() {
    let engine = SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    engine.start()
    #expect(engine.state == .listening)
    engine.cancel()
    #expect(engine.state == .idle)
  }
}
