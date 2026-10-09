@preconcurrency import AVFoundation
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

@MainActor
private final class PreparationDelegate: VoiceInputDelegate {
  var statuses: [VoiceInputEngineStatus?] = []
  var errors: [VoiceInputEngineError] = []
  func voiceInput(didFinalize text: String) {}
  func voiceInput(didUpdateVolatile text: String) {}
  func voiceInput(didEncounterError error: VoiceInputEngineError) { errors.append(error) }
  func voiceInput(didUpdateStatus status: VoiceInputEngineStatus?) { statuses.append(status) }
}

private enum PreparationStage: CaseIterable, Sendable {
  case permission, model, format
}

private enum PreparationFailure: Error { case delayed }

extension SpeechAnalyzerEngineTests {
  @Test(arguments: PreparationStage.allCases, [(false, false), (false, true), (true, false), (true, true)])
  fileprivate func endedPreparationCannotStartOrOverwriteNextStart(
    stage: PreparationStage, ending: (stop: Bool, fail: Bool)
  ) async throws {
    let (stop, fail) = ending
    let oldWait = SpeechPreparationSuspension<Bool>()
    let nextWait = SpeechPreparationSuspension<Bool>()
    let delegate = PreparationDelegate()
    let access = AudioInputExclusiveAccess()
    var acquires = 0
    access.markAsActive { acquires += 1 }
    var permissionCalls = 0
    var modelCalls = 0
    var inputCalls = 0
    var formatCalls = 0
    weak var createdAudio: AVAudioEngine?
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
    var dependencies = SpeechAnalyzerEngine.Dependencies()
    dependencies.permissionAction = { .requestAccess }
    dependencies.requestAccess = {
      permissionCalls += 1
      if permissionCalls > 1 { return await nextWait.wait() }
      if stage == .permission { return await oldWait.wait() }
      return true
    }
    dependencies.installationRequest = { _ in
      modelCalls += 1
      if stage == .model {
        let success = await oldWait.wait()
        if !success { throw PreparationFailure.delayed }
      }
      return nil
    }
    dependencies.inputFormat = { audio, _ in
      inputCalls += 1
      createdAudio = audio
      return format
    }
    dependencies.bestFormat = { _, _ in
      formatCalls += 1
      if stage == .format { return await oldWait.wait() ? format : nil }
      return format
    }
    let engine = SpeechAnalyzerEngine(
      locale: Locale(identifier: "ja-JP"), deviceUID: nil,
      verificationCache: SpeechModelVerificationCache(), audioInputExclusiveAccess: access,
      dependencies: dependencies
    )
    engine.delegate = delegate
    engine.start()
    let oldTask = try #require(engine.startTask)
    await oldWait.waitForArrival()
    if stop { await engine.stop() } else { engine.cancel() }
    #expect(engine.state == .idle)
    #expect(delegate.statuses.last == .some(nil))
    #expect(acquires == 0)
    #expect(createdAudio?.isRunning != true)

    engine.start()
    let nextTask = try #require(engine.startTask)
    await nextWait.waitForArrival()
    let statusesBeforeOldReturn = delegate.statuses
    oldWait.resume(returning: !fail)
    await oldTask.value
    #expect(engine.state == .listening)
    #expect(delegate.statuses == statusesBeforeOldReturn)
    #expect(delegate.errors.isEmpty)
    #expect(acquires == 0)
    #expect(createdAudio?.isRunning != true)
    #expect(modelCalls == (stage == .permission ? 0 : 1))
    #expect(inputCalls == (stage == .format ? 1 : 0))
    #expect(formatCalls == (stage == .format ? 1 : 0))
    #expect(createdAudio == nil)

    engine.cancel()
    nextWait.resume(returning: false)
    await nextTask.value
    #expect(engine.state == .idle)
    #expect(delegate.errors.isEmpty)
    #expect(acquires == 0)
    access.clearActive()
  }

  @Test func activePreparationStillReportsFormatFailure() async throws {
    let arrived = SpeechPreparationSuspension<Bool>()
    var dependencies = SpeechAnalyzerEngine.Dependencies()
    dependencies.permissionAction = { .proceed }
    dependencies.installationRequest = { _ in nil }
    dependencies.inputFormat = { _, _ in
      AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
    }
    dependencies.bestFormat = { _, _ in
      _ = await arrived.wait()
      return nil
    }
    let delegate = PreparationDelegate()
    let engine = SpeechAnalyzerEngine(
      locale: Locale(identifier: "ja-JP"), deviceUID: nil,
      verificationCache: SpeechModelVerificationCache(),
      audioInputExclusiveAccess: AudioInputExclusiveAccess(), dependencies: dependencies
    )
    engine.delegate = delegate
    engine.start()
    let task = try #require(engine.startTask)
    await arrived.waitForArrival()
    arrived.resume(returning: true)
    await task.value
    #expect(delegate.errors == [.noCompatibleAudioFormat])
    #expect(engine.state != .listening)
    engine.cancel()
  }
}
