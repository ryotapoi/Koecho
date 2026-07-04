import Foundation
import KoechoCore

@testable import Koecho

@MainActor
final class MockVoiceInputEngine: VoiceInputEngine {
  private(set) var state: VoiceInputState = .idle
  weak var delegate: (any VoiceInputDelegate)?

  var startCallCount = 0
  var stopCallCount = 0
  var cancelCallCount = 0

  func start() {
    startCallCount += 1
    state = .listening
  }

  func stop() async {
    stopCallCount += 1
    state = .stopping
    state = .idle
  }

  func cancel() {
    cancelCallCount += 1
    state = .idle
  }
}

@MainActor
final class MockRestartableVoiceInputEngine: VoiceInputEngine, TranscriberRestartable {
  private(set) var state: VoiceInputState = .idle
  weak var delegate: (any VoiceInputDelegate)?

  var restartResult = true
  var startCallCount = 0
  var stopCallCount = 0
  var cancelCallCount = 0
  var restartTranscriberCallCount = 0

  func start() {
    startCallCount += 1
    state = .listening
  }

  func stop() async {
    stopCallCount += 1
    state = .stopping
    state = .idle
  }

  func cancel() {
    cancelCallCount += 1
    state = .idle
  }

  @discardableResult
  func restartTranscriber() async -> Bool {
    restartTranscriberCallCount += 1
    return restartResult
  }
}
