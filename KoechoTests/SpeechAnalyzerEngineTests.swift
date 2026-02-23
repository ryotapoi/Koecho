import Foundation
import Testing
@testable import Koecho

@MainActor
@Suite(.serialized)
struct SpeechAnalyzerEngineTests {
    private func makeEngine() -> (any VoiceInputEngine)? {
        guard #available(macOS 26, *) else { return nil }
        return SpeechAnalyzerEngine(locale: Locale(identifier: "ja-JP"))
    }

    @Test func initialStateIsIdle() {
        guard let engine = makeEngine() else { return }
        #expect(engine.state == .idle)
    }

    @Test func startWhenAlreadyListeningIsNoop() {
        guard let engine = makeEngine() else { return }
        engine.start()
        #expect(engine.state == .listening)
        // Second start should be no-op (state stays listening)
        engine.start()
        #expect(engine.state == .listening)
        engine.cancel()
    }

    @Test func cancelFromIdleRemainsIdle() {
        guard let engine = makeEngine() else { return }
        engine.cancel()
        #expect(engine.state == .idle)
    }

    @Test func cancelFromListeningGoesToIdle() {
        guard let engine = makeEngine() else { return }
        engine.start()
        engine.cancel()
        #expect(engine.state == .idle)
    }

    @Test func stopFromIdleRemainsIdle() async {
        guard let engine = makeEngine() else { return }
        await engine.stop()
        #expect(engine.state == .idle)
    }

    @Test func delegateIsRetained() {
        guard #available(macOS 26, *) else { return }
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
    var errors: [String] = []
    var statuses: [String?] = []

    func voiceInput(didFinalize text: String) {
        finalizedTexts.append(text)
    }

    func voiceInput(didUpdateVolatile text: String) {
        volatileTexts.append(text)
    }

    func voiceInput(didEncounterError message: String) {
        errors.append(message)
    }

    func voiceInput(didUpdateStatus status: String?) {
        statuses.append(status)
    }
}
