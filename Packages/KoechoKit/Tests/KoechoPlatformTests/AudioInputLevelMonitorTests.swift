import AudioToolbox
import Testing

@testable import KoechoPlatform

@MainActor
struct AudioInputLevelMonitorTests {
  @Test(arguments: [false, true])
  func recognitionReleaseResumesRequestedCapture(recognitionFirst: Bool) {
    let access = AudioInputExclusiveAccess()
    let capture = Capture()
    let monitor = AudioInputLevelMonitor(
      exclusiveAccess: access, audioInput: (capture.start, capture.stop))
    if recognitionFirst { access.acquire() }
    monitor.start(deviceID: 11)
    if !recognitionFirst { access.acquire() }
    #expect(capture.deviceID == nil)
    #expect(access.isInUse)

    access.release()
    #expect(capture.deviceID == 11)
    #expect(access.isInUse)
    access.acquire()
    #expect(capture.deviceID == nil)
    access.release()
    #expect(capture.deviceID == 11)
    // A duplicate release must not clear the active monitor or restart its capture.
    access.release()
    #expect(capture.deviceID == 11)
    monitor.stop()
    #expect(!access.isInUse)
  }

  @Test func stoppedRequestDoesNotResumeButCanBeEnabledAgain() {
    let access = AudioInputExclusiveAccess()
    let capture = Capture()
    let monitor = AudioInputLevelMonitor(
      exclusiveAccess: access, audioInput: (capture.start, capture.stop))
    monitor.start(deviceID: 11)
    access.acquire()
    // Used by both Settings disappearance and Voice off.
    monitor.stop()
    access.release()
    #expect(capture.deviceID == nil)
    #expect(!access.isInUse)
    monitor.start(deviceID: 22)
    #expect(capture.deviceID == 22)
  }

  @Test func pendingRequestUsesLatestTargetAndCanBeRemoved() {
    let access = AudioInputExclusiveAccess()
    let capture = Capture()
    let monitor = AudioInputLevelMonitor(
      exclusiveAccess: access, audioInput: (capture.start, capture.stop))
    access.acquire()
    monitor.start(deviceID: 11)
    monitor.start(deviceID: 22)
    #expect(capture.deviceID == nil)
    #expect(access.isInUse)
    access.release()
    #expect(capture.deviceID == 22)
    access.acquire()
    // AudioDeviceManager tears down the request when no target remains.
    monitor.stop()
    access.release()
    #expect(capture.deviceID == nil)
  }

  @Test(arguments: [false, true])
  func ownerDestructionCancelsCaptureAndResume(recognitionActive: Bool) {
    let access = AudioInputExclusiveAccess()
    let capture = Capture()
    var monitor: AudioInputLevelMonitor? = AudioInputLevelMonitor(
      exclusiveAccess: access, audioInput: (capture.start, capture.stop))
    monitor?.start(deviceID: 11)
    if recognitionActive { access.acquire() }
    monitor = nil
    #expect(capture.deviceID == nil)
    #expect(access.isInUse == recognitionActive)
    access.release()
    #expect(capture.deviceID == nil)
    #expect(!access.isInUse)
  }

  @MainActor
  private final class Capture {
    var deviceID: AudioDeviceID?

    func start(_ deviceID: AudioDeviceID?) -> Bool {
      self.deviceID = deviceID
      return true
    }

    func stop() { deviceID = nil }
  }

  @Test func stopWithoutStartKeepsInputLevelZero() {
    let monitor = AudioInputLevelMonitor()
    monitor.stop()
    #expect(monitor.inputLevel == 0)
  }

  @Test func inputLevelReturnsNilWithoutFrames() {
    withAudioBufferList(channels: [[1]]) { buffers in
      #expect(AudioInputLevelMonitor.inputLevel(buffers: buffers, frameCount: 0) == nil)
    }
  }

  @Test func inputLevelReturnsNilWithoutChannels() {
    withAudioBufferList(channels: []) { buffers in
      #expect(AudioInputLevelMonitor.inputLevel(buffers: buffers, frameCount: 1) == nil)
    }
  }

  @Test func inputLevelNormalizesSilenceToZero() {
    withAudioBufferList(channels: [[0, 0, 0]]) { buffers in
      #expect(AudioInputLevelMonitor.inputLevel(buffers: buffers, frameCount: 3) == 0)
    }
  }

  @Test func inputLevelNormalizesFullScaleSamplesToOne() {
    withAudioBufferList(channels: [[1, -1, 1]]) { buffers in
      #expect(AudioInputLevelMonitor.inputLevel(buffers: buffers, frameCount: 3) == 1)
    }
  }

  @Test func inputLevelNormalizesDecibelRange() {
    withAudioBufferList(channels: [[0.1, -0.1]]) { buffers in
      let level = AudioInputLevelMonitor.inputLevel(buffers: buffers, frameCount: 2)

      #expect(level != nil)
      #expect(isApproximately(level!, 2.0 / 3.0, tolerance: 0.0001))
    }
  }

  @Test func inputLevelAveragesAcrossChannels() {
    withAudioBufferList(channels: [[1, 0], [0, 0]]) { buffers in
      let level = AudioInputLevelMonitor.inputLevel(buffers: buffers, frameCount: 2)

      #expect(level != nil)
      #expect(isApproximately(level!, 0.8997, tolerance: 0.0001))
    }
  }

  @Test func shouldPublishLevelRequiresFiftyMilliseconds() {
    let lastUpdate = ContinuousClock.now

    #expect(
      !AudioInputLevelMonitor.shouldPublishLevel(
        now: lastUpdate + .milliseconds(49),
        lastUpdate: lastUpdate
      ))
    #expect(
      AudioInputLevelMonitor.shouldPublishLevel(
        now: lastUpdate + .milliseconds(50),
        lastUpdate: lastUpdate
      ))
  }

  private func withAudioBufferList<T>(
    channels: [[Float32]],
    _ body: (UnsafeMutableAudioBufferListPointer) -> T
  ) -> T {
    let buffers = AudioBufferList.allocate(maximumBuffers: max(channels.count, 1))
    buffers.count = channels.count

    var allocatedSamples: [UnsafeMutableBufferPointer<Float32>] = []
    allocatedSamples.reserveCapacity(channels.count)

    defer {
      for samples in allocatedSamples {
        samples.deallocate()
      }
      buffers.unsafeMutablePointer.deallocate()
    }

    for (index, channel) in channels.enumerated() {
      let samples = UnsafeMutableBufferPointer<Float32>.allocate(capacity: channel.count)
      _ = samples.initialize(from: channel)
      allocatedSamples.append(samples)

      buffers[index] = AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: UInt32(channel.count * MemoryLayout<Float32>.size),
        mData: UnsafeMutableRawPointer(samples.baseAddress)
      )
    }

    return body(buffers)
  }

  private func isApproximately(_ lhs: Float, _ rhs: Float, tolerance: Float) -> Bool {
    abs(lhs - rhs) <= tolerance
  }
}
