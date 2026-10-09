import AudioToolbox
import CoreAudio
import Foundation
import KoechoCore
import Observation
import os

@MainActor @Observable
final class AudioInputLevelMonitor {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "AudioInputLevelMonitor")
  @ObservationIgnored private let exclusiveAccess: AudioInputExclusiveAccess

  @ObservationIgnored private var resumeID: UUID?
  @ObservationIgnored private var activeID: UUID?
  @ObservationIgnored private var requestedDeviceID: AudioDeviceID?
  @ObservationIgnored private let audioInput: (
    start: (AudioDeviceID?) -> Bool, stop: () -> Void
  )?

  private(set) var inputLevel: Float = 0

  // Accessed from the AUHAL input callback on the audio I/O thread.
  // Safe because start/stop are serialized on @MainActor and the callback
  // only runs between start and stop.
  @ObservationIgnored private nonisolated(unsafe) var monitoringAudioUnit: AudioComponentInstance?
  @ObservationIgnored private nonisolated(unsafe) var monitoringBufferList:
    UnsafeMutableAudioBufferListPointer?
  @ObservationIgnored private nonisolated(unsafe) var lastLevelUpdate: ContinuousClock.Instant =
    .now

  init(
    exclusiveAccess: AudioInputExclusiveAccess = .shared,
    audioInput: (start: (AudioDeviceID?) -> Bool, stop: () -> Void)? = nil
  ) {
    self.exclusiveAccess = exclusiveAccess
    self.audioInput = audioInput
  }

  nonisolated static func inputLevel(
    buffers: UnsafeMutableAudioBufferListPointer,
    frameCount: Int
  ) -> Float? {
    guard frameCount > 0, buffers.count > 0 else { return nil }

    var sumOfSquares: Float = 0
    for ch in 0..<buffers.count {
      guard let data = buffers[ch].mData else { continue }
      let samples = data.assumingMemoryBound(to: Float32.self)
      for frame in 0..<frameCount {
        let sample = samples[frame]
        sumOfSquares += sample * sample
      }
    }

    let rms = sqrtf(sumOfSquares / Float(frameCount * buffers.count))
    let db = 20 * log10f(max(rms, 1e-7))
    return max(0, min(1, (db + 60) / 60))
  }

  nonisolated static func shouldPublishLevel(
    now: ContinuousClock.Instant,
    lastUpdate: ContinuousClock.Instant
  ) -> Bool {
    now - lastUpdate >= .milliseconds(50)
  }

  func start(deviceID: AudioDeviceID?) {
    stop()

    requestedDeviceID = deviceID
    resumeID = exclusiveAccess.resumeMonitoringOnRelease { [weak self] in
      self?.resume()
    }
    resume()
  }

  private func resume() {
    guard resumeID != nil, activeID == nil, !exclusiveAccess.isInUse else { return }
    let started = audioInput.map { $0.start(requestedDeviceID) }
      ?? startAudioInput(deviceID: requestedDeviceID)
    guard started else { return }
    activeID = exclusiveAccess.markAsActive { [weak self] in
      self?.stopCapture()
    }
  }

  private func startAudioInput(deviceID: AudioDeviceID?) -> Bool {
    guard !exclusiveAccess.isInUse else {
      logger.info("Audio input in use by another component, skipping level monitoring")
      return false
    }

    let effectiveDeviceID =
      deviceID ?? AudioDeviceListing.defaultInputDeviceID() ?? kAudioObjectUnknown
    guard effectiveDeviceID != kAudioObjectUnknown else {
      logger.warning("No input device available for level monitoring")
      return false
    }

    logger.info(
      "Starting level monitoring AUHAL (deviceID: \(effectiveDeviceID, privacy: .public))")

    // 1. Find and create the AUHAL component
    var desc = AudioComponentDescription(
      componentType: kAudioUnitType_Output,
      componentSubType: kAudioUnitSubType_HALOutput,
      componentManufacturer: kAudioUnitManufacturer_Apple,
      componentFlags: 0,
      componentFlagsMask: 0
    )
    guard let component = AudioComponentFindNext(nil, &desc) else {
      logger.warning("AUHAL component not found")
      return false
    }

    var unit: AudioComponentInstance?
    guard AudioComponentInstanceNew(component, &unit) == noErr, let unit else {
      logger.warning("Failed to create AUHAL instance")
      return false
    }

    // On any failure below, dispose the unit and clean up buffers
    var initialized = false
    defer {
      if monitoringAudioUnit == nil {
        // Setup did not complete — clean up
        if initialized { AudioUnitUninitialize(unit) }
        deallocateBufferList()
        AudioComponentInstanceDispose(unit)
      }
    }

    // 2. Enable input on Element 1, disable output on Element 0
    let inputBus: AudioUnitElement = 1
    let outputBus: AudioUnitElement = 0
    let sizeOfUInt32 = UInt32(MemoryLayout<UInt32>.size)

    var enableInput: UInt32 = 1
    guard
      AudioUnitSetProperty(
        unit, kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Input, inputBus,
        &enableInput, sizeOfUInt32
      ) == noErr
    else {
      logger.warning("Failed to enable AUHAL input")
      return false
    }

    var disableOutput: UInt32 = 0
    guard
      AudioUnitSetProperty(
        unit, kAudioOutputUnitProperty_EnableIO,
        kAudioUnitScope_Output, outputBus,
        &disableOutput, sizeOfUInt32
      ) == noErr
    else {
      logger.warning("Failed to disable AUHAL output")
      return false
    }

    // 3. Set the input device (after enabling IO, before AudioUnitInitialize)
    var devID = effectiveDeviceID
    guard
      AudioUnitSetProperty(
        unit, kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global, 0,
        &devID, UInt32(MemoryLayout<AudioDeviceID>.size)
      ) == noErr
    else {
      logger.warning("Failed to set AUHAL input device")
      return false
    }

    // 4. Get device's native format (Input scope of Element 1)
    var deviceFormat = AudioStreamBasicDescription()
    var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    guard
      AudioUnitGetProperty(
        unit, kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input, inputBus,
        &deviceFormat, &formatSize
      ) == noErr, deviceFormat.mChannelsPerFrame > 0
    else {
      logger.warning("Failed to get AUHAL device format or no channels")
      return false
    }

    // 5. Set desired output format (Output scope of Element 1): non-interleaved Float32
    var desiredFormat = AudioStreamBasicDescription(
      mSampleRate: deviceFormat.mSampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kLinearPCMFormatFlagIsNonInterleaved,
      mBytesPerPacket: UInt32(MemoryLayout<Float32>.size),
      mFramesPerPacket: 1,
      mBytesPerFrame: UInt32(MemoryLayout<Float32>.size),
      mChannelsPerFrame: deviceFormat.mChannelsPerFrame,
      mBitsPerChannel: UInt32(MemoryLayout<Float32>.size * 8),
      mReserved: 0
    )
    guard
      AudioUnitSetProperty(
        unit, kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output, inputBus,
        &desiredFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
      ) == noErr
    else {
      logger.warning("Failed to set AUHAL desired format")
      return false
    }

    // 6. Allocate AudioBufferList (one buffer per channel, non-interleaved)
    let channelCount = Int(desiredFormat.mChannelsPerFrame)
    var maxFrames: UInt32 = 4096
    var maxFramesSize = UInt32(MemoryLayout<UInt32>.size)
    AudioUnitGetProperty(
      unit, kAudioUnitProperty_MaximumFramesPerSlice,
      kAudioUnitScope_Global, 0,
      &maxFrames, &maxFramesSize
    )

    let abl = AudioBufferList.allocate(maximumBuffers: channelCount)
    abl.count = channelCount
    for i in 0..<channelCount {
      let byteSize = desiredFormat.mBytesPerFrame * maxFrames
      abl[i] = AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: byteSize,
        mData: malloc(Int(byteSize))
      )
    }
    monitoringBufferList = abl

    // 7. Install input callback
    var callbackStruct = AURenderCallbackStruct(
      inputProc: Self.auhalInputCallback,
      inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
    )
    guard
      AudioUnitSetProperty(
        unit, kAudioOutputUnitProperty_SetInputCallback,
        kAudioUnitScope_Global, 0,
        &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size)
      ) == noErr
    else {
      logger.warning("Failed to set AUHAL input callback")
      return false
    }

    // 8. Initialize and start
    guard AudioUnitInitialize(unit) == noErr else {
      logger.warning("Failed to initialize AUHAL")
      return false
    }
    initialized = true

    guard AudioOutputUnitStart(unit) == noErr else {
      logger.warning("Failed to start AUHAL")
      return false
    }

    // Success — transfer ownership
    monitoringAudioUnit = unit
    logger.info("Level monitoring AUHAL started")
    return true
  }

  func stop() {
    if let resumeID { exclusiveAccess.cancelMonitoringResume(resumeID) }
    resumeID = nil
    requestedDeviceID = nil
    stopCapture()
  }

  private func stopCapture() {
    guard let activeID else { return }
    if let audioInput {
      audioInput.stop()
    } else if let unit = monitoringAudioUnit {
      AudioOutputUnitStop(unit)
      AudioUnitUninitialize(unit)
      AudioComponentInstanceDispose(unit)
      monitoringAudioUnit = nil
      deallocateBufferList()
    }
    exclusiveAccess.clearActive(activeID)
    self.activeID = nil
    inputLevel = 0
    logger.info("Level monitoring AUHAL stopped")
  }

  isolated deinit {
    stop()
  }

  // MARK: - Private

  private func deallocateBufferList() {
    guard let abl = monitoringBufferList else { return }
    for i in 0..<abl.count {
      free(abl[i].mData)
    }
    abl.unsafeMutablePointer.deallocate()
    monitoringBufferList = nil
  }

  // C-compatible AUHAL input callback. Runs on the audio I/O thread.
  // Must not allocate memory, take locks, or do ObjC messaging.
  private nonisolated static let auhalInputCallback: AURenderCallback = {
    (
      inRefCon: UnsafeMutableRawPointer,
      ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
      inTimeStamp: UnsafePointer<AudioTimeStamp>,
      inBusNumber: UInt32,
      inNumberFrames: UInt32,
      ioData: UnsafeMutablePointer<AudioBufferList>?
    ) -> OSStatus in

    let monitor = Unmanaged<AudioInputLevelMonitor>.fromOpaque(inRefCon).takeUnretainedValue()
    guard let audioUnit = monitor.monitoringAudioUnit,
      let abl = monitor.monitoringBufferList
    else {
      return noErr
    }

    // Reset buffer sizes for this render cycle
    let bytesPerFrame = UInt32(MemoryLayout<Float32>.size)
    for i in 0..<abl.count {
      abl[i].mDataByteSize = bytesPerFrame * inNumberFrames
    }

    // Pull audio data from the AUHAL
    let status = AudioUnitRender(
      audioUnit, ioActionFlags, inTimeStamp,
      inBusNumber, inNumberFrames,
      abl.unsafeMutablePointer
    )
    guard status == noErr else { return status }

    guard
      let normalized = AudioInputLevelMonitor.inputLevel(
        buffers: abl,
        frameCount: Int(inNumberFrames)
      )
    else {
      return noErr
    }

    // Throttle: skip if less than 50ms since last update
    let now = ContinuousClock.now
    guard AudioInputLevelMonitor.shouldPublishLevel(now: now, lastUpdate: monitor.lastLevelUpdate)
    else {
      return noErr
    }
    monitor.lastLevelUpdate = now

    Task { @MainActor [weak monitor] in
      monitor?.inputLevel = normalized
    }

    return noErr
  }
}
