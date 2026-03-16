import AudioToolbox
import CoreAudio
import KoechoCore
import Observation
import os

@MainActor @Observable
final class AudioInputLevelMonitor {
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "AudioInputLevelMonitor")

    private(set) var inputLevel: Float = 0

    // Accessed from the AUHAL input callback on the audio I/O thread.
    // Safe because start/stop are serialized on @MainActor and the callback
    // only runs between start and stop.
    @ObservationIgnored private nonisolated(unsafe) var monitoringAudioUnit: AudioComponentInstance?
    @ObservationIgnored private nonisolated(unsafe) var monitoringBufferList: UnsafeMutableAudioBufferListPointer?
    @ObservationIgnored private nonisolated(unsafe) var lastLevelUpdate: ContinuousClock.Instant = .now

    func start(deviceID: AudioDeviceID?) {
        stop()

        guard !AudioInputExclusiveAccess.isInUse else {
            logger.info("Audio input in use by another component, skipping level monitoring")
            return
        }

        let effectiveDeviceID = deviceID ?? AudioDeviceListing.defaultInputDeviceID() ?? kAudioObjectUnknown
        guard effectiveDeviceID != kAudioObjectUnknown else {
            logger.warning("No input device available for level monitoring")
            return
        }

        logger.info("Starting level monitoring AUHAL (deviceID: \(effectiveDeviceID, privacy: .public))")

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
            return
        }

        var unit: AudioComponentInstance?
        guard AudioComponentInstanceNew(component, &unit) == noErr, let unit else {
            logger.warning("Failed to create AUHAL instance")
            return
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
        guard AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input, inputBus,
            &enableInput, sizeOfUInt32
        ) == noErr else {
            logger.warning("Failed to enable AUHAL input"); return
        }

        var disableOutput: UInt32 = 0
        guard AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output, outputBus,
            &disableOutput, sizeOfUInt32
        ) == noErr else {
            logger.warning("Failed to disable AUHAL output"); return
        }

        // 3. Set the input device (after enabling IO, before AudioUnitInitialize)
        var devID = effectiveDeviceID
        guard AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0,
            &devID, UInt32(MemoryLayout<AudioDeviceID>.size)
        ) == noErr else {
            logger.warning("Failed to set AUHAL input device"); return
        }

        // 4. Get device's native format (Input scope of Element 1)
        var deviceFormat = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioUnitGetProperty(
            unit, kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input, inputBus,
            &deviceFormat, &formatSize
        ) == noErr, deviceFormat.mChannelsPerFrame > 0 else {
            logger.warning("Failed to get AUHAL device format or no channels"); return
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
        guard AudioUnitSetProperty(
            unit, kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output, inputBus,
            &desiredFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        ) == noErr else {
            logger.warning("Failed to set AUHAL desired format"); return
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
        guard AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global, 0,
            &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        ) == noErr else {
            logger.warning("Failed to set AUHAL input callback"); return
        }

        // 8. Initialize and start
        guard AudioUnitInitialize(unit) == noErr else {
            logger.warning("Failed to initialize AUHAL"); return
        }
        initialized = true

        guard AudioOutputUnitStart(unit) == noErr else {
            logger.warning("Failed to start AUHAL"); return
        }

        // Success — transfer ownership
        monitoringAudioUnit = unit
        AudioInputExclusiveAccess.markAsActive { [weak self] in
            self?.stop()
        }
        logger.info("Level monitoring AUHAL started")
    }

    func stop() {
        guard let unit = monitoringAudioUnit else { return }
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        monitoringAudioUnit = nil
        deallocateBufferList()
        AudioInputExclusiveAccess.clearActive()
        inputLevel = 0
        logger.info("Level monitoring AUHAL stopped")
    }

    deinit {
        // deinit is nonisolated — call CoreAudio C API directly.
        stopSync()
    }

    // MARK: - Private

    private nonisolated func stopSync() {
        let hadAudioUnit = monitoringAudioUnit != nil
        if let unit = monitoringAudioUnit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
            monitoringAudioUnit = nil
        }
        if let abl = monitoringBufferList {
            for i in 0..<abl.count {
                free(abl[i].mData)
            }
            abl.unsafeMutablePointer.deallocate()
            monitoringBufferList = nil
        }

        // AudioInputExclusiveAccess is @MainActor so dispatch asynchronously.
        if hadAudioUnit {
            Task { @MainActor in
                AudioInputExclusiveAccess.clearActive()
            }
        }
    }

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
              let abl = monitor.monitoringBufferList else {
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

        // Calculate RMS across all channels
        let channelCount = abl.count
        let frameCount = Int(inNumberFrames)
        guard frameCount > 0, channelCount > 0 else { return noErr }

        var sumOfSquares: Float = 0
        for ch in 0..<channelCount {
            guard let data = abl[ch].mData else { continue }
            let samples = data.assumingMemoryBound(to: Float32.self)
            for frame in 0..<frameCount {
                let sample = samples[frame]
                sumOfSquares += sample * sample
            }
        }

        let rms = sqrtf(sumOfSquares / Float(frameCount * channelCount))
        let db = 20 * log10f(max(rms, 1e-7))
        let normalized = max(0, min(1, (db + 60) / 60))

        // Throttle: skip if less than 50ms since last update
        let now = ContinuousClock.now
        guard now - monitor.lastLevelUpdate >= .milliseconds(50) else { return noErr }
        monitor.lastLevelUpdate = now

        Task { @MainActor [weak monitor] in
            monitor?.inputLevel = normalized
        }

        return noErr
    }
}
