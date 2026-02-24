import AudioToolbox
import CoreAudio
import os

struct AudioInputDevice: Identifiable, Equatable {
    let audioDeviceID: AudioDeviceID
    let uid: String
    let name: String
    let supportsVolumeControl: Bool
    var id: String { uid }
}

@MainActor @Observable
final class AudioDeviceManager {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "AudioDeviceManager")

    private(set) var inputDevices: [AudioInputDevice] = []
    private(set) var inputLevel: Float = 0
    private(set) var inputVolume: Float = 0
    private(set) var isMonitoring: Bool = false
    private(set) var monitoredDeviceSupportsVolume: Bool = false

    // MARK: - Exclusive access (static, @MainActor)

    private(set) static var isAudioInputInUse = false
    private static weak var activeMonitoringInstance: AudioDeviceManager?

    static func acquireAudioInput() {
        // Stop any active monitoring engine before another component takes over
        activeMonitoringInstance?.stopEngine()
        isAudioInputInUse = true
    }

    static func releaseAudioInput() {
        isAudioInputInUse = false
    }

    // MARK: - Private state

    // nonisolated(unsafe) because the AUHAL input callback accesses these
    // from the audio I/O thread. Safe because start/stop are serialized on
    // @MainActor and the callback only runs between start and stop.
    private nonisolated(unsafe) var monitoringAudioUnit: AudioComponentInstance?
    private nonisolated(unsafe) var monitoringBufferList: UnsafeMutableAudioBufferListPointer?
    private nonisolated(unsafe) var lastLevelUpdate: ContinuousClock.Instant = .now

    private var monitoringDeviceUID: String?
    private var monitoredDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isUpdatingVolume = false

    // CoreAudio listener blocks (retained for removal in deinit).
    // nonisolated(unsafe) so deinit (which is nonisolated) can access them.
    // Safe because no concurrent access occurs at deinitialization time.
    private nonisolated(unsafe) var deviceListListenerBlock: AudioObjectPropertyListenerBlock?
    private nonisolated(unsafe) var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private nonisolated(unsafe) var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private nonisolated(unsafe) var volumeListenerDeviceID: AudioDeviceID = kAudioObjectUnknown
    private nonisolated(unsafe) var volumeListenerElement: AudioObjectPropertyElement = kAudioObjectPropertyElementMain

    // MARK: - Init / Deinit

    init() {
        refreshDevices()
        installDeviceListListener()
        installDefaultDeviceListener()
    }

    deinit {
        // deinit is nonisolated, so access nonisolated(unsafe) properties directly
        // and call CoreAudio C functions (which are safe from any thread).

        // Stop and dispose AUHAL to prevent dangling callback pointer
        let hadAudioUnit = monitoringAudioUnit != nil
        if let unit = monitoringAudioUnit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
        if let abl = monitoringBufferList {
            for i in 0..<abl.count {
                free(abl[i].mData)
            }
            abl.unsafeMutablePointer.deallocate()
        }

        // Reset exclusive access flag if this instance owned the AUHAL.
        // isAudioInputInUse is @MainActor so dispatch asynchronously.
        if hadAudioUnit {
            Task { @MainActor in
                AudioDeviceManager.isAudioInputInUse = false
                AudioDeviceManager.activeMonitoringInstance = nil
            }
        }

        // Remove property listener blocks
        if let block = deviceListListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address,
                DispatchQueue.main, block
            )
        }
        if let block = defaultDeviceListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address,
                DispatchQueue.main, block
            )
        }
        if let block = volumeListenerBlock, volumeListenerDeviceID != kAudioObjectUnknown {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: volumeListenerElement
            )
            AudioObjectRemovePropertyListenerBlock(
                volumeListenerDeviceID, &address,
                DispatchQueue.main, block
            )
        }
    }

    // MARK: - Public API

    func refreshDevices() {
        inputDevices = Self.enumerateInputDevices()
    }

    func startMonitoring(deviceUID: String?) {
        stopMonitoring()

        // Resolve effective device ID.
        // If a specific UID is given but not found, fall back to system default
        // and clear monitoringDeviceUID so default device changes are tracked.
        var effectiveUID = deviceUID
        var deviceID: AudioDeviceID?
        if let uid = deviceUID {
            deviceID = Self.resolveDeviceID(forUID: uid)
            if deviceID == nil {
                logger.warning("Device UID '\(uid, privacy: .public)' not found, falling back to system default")
                effectiveUID = nil
            }
        }
        if deviceID == nil {
            deviceID = Self.defaultInputDeviceID()
        }

        guard let deviceID else {
            logger.warning("No input device available for monitoring")
            return
        }

        monitoringDeviceUID = effectiveUID
        monitoredDeviceID = deviceID
        setupVolumeMonitoring(for: deviceID)
        startEngineIfAvailable(deviceID: effectiveUID != nil ? deviceID : nil)
        isMonitoring = true
    }

    func stopMonitoring() {
        stopEngine()
        removeVolumeListener()
        monitoredDeviceID = kAudioObjectUnknown
        monitoredDeviceSupportsVolume = false
        inputLevel = 0
        inputVolume = 0
        isMonitoring = false
    }

    func setInputVolume(_ volume: Float) {
        guard monitoredDeviceID != kAudioObjectUnknown else { return }
        let clamped = max(0, min(1, volume))

        let element = volumeElement(for: monitoredDeviceID)
        guard element != kAudioObjectPropertyElementMain || Self.supportsVolumeOnElement(monitoredDeviceID, element: kAudioObjectPropertyElementMain) else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )

        isUpdatingVolume = true
        var value = clamped
        let status = AudioObjectSetPropertyData(
            monitoredDeviceID, &address, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &value
        )
        if status == noErr {
            inputVolume = clamped
        } else {
            logger.warning("Failed to set input volume (status: \(status))")
        }
        isUpdatingVolume = false
    }

    // MARK: - Static helpers

    static func resolveDeviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfUID: CFString = uid as CFString
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)

        let status = withUnsafeMutablePointer(to: &cfUID) { uidPtr in
            withUnsafeMutablePointer(to: &deviceID) { devicePtr in
                var translation = AudioValueTranslation(
                    mInputData: uidPtr,
                    mInputDataSize: UInt32(MemoryLayout<CFString>.size),
                    mOutputData: devicePtr,
                    mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                return AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                    &size, &translation
                )
            }
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    // MARK: - Device enumeration

    private static func enumerateInputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { deviceID -> AudioInputDevice? in
            guard !isAggregateDevice(deviceID) else { return nil }
            guard hasInputChannels(deviceID) else { return nil }
            guard let uid = deviceUID(for: deviceID) else { return nil }
            let name = deviceName(for: deviceID) ?? uid
            let supportsVolume = supportsVolumeControl(deviceID)
            return AudioInputDevice(
                audioDeviceID: deviceID,
                uid: uid,
                name: name,
                supportsVolumeControl: supportsVolume
            )
        }
    }

    private static func isAggregateDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyClass,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var classID: AudioClassID = 0
        var size = UInt32(MemoryLayout<AudioClassID>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &classID
        ) == noErr else { return false }
        return classID == kAudioAggregateDeviceClassID
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size > 0 else { return false }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }
        let ablPointer = rawPointer.assumingMemoryBound(to: AudioBufferList.self)

        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, ablPointer
        ) == noErr else { return false }

        let abl = UnsafeMutableAudioBufferListPointer(ablPointer)
        return abl.contains { $0.mNumberChannels > 0 }
    }

    private static func deviceUID(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return getStringProperty(deviceID: deviceID, address: &address)
    }

    private static func deviceName(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return getStringProperty(deviceID: deviceID, address: &address)
    }

    private static func getStringProperty(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> String? {
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &value
        ) == noErr, let cfString = value else { return nil }
        return cfString.takeRetainedValue() as String
    }

    private static func supportsVolumeControl(_ deviceID: AudioDeviceID) -> Bool {
        supportsVolumeOnElement(deviceID, element: kAudioObjectPropertyElementMain)
            || supportsVolumeOnElement(deviceID, element: 1)
    }

    private static func supportsVolumeOnElement(_ deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr else { return false }
        return settable.boolValue
    }

    // MARK: - Volume monitoring

    private func setupVolumeMonitoring(for deviceID: AudioDeviceID) {
        removeVolumeListener()

        let element = volumeElement(for: deviceID)
        monitoredDeviceSupportsVolume = Self.supportsVolumeControl(deviceID)

        // Read current volume
        if monitoredDeviceSupportsVolume {
            inputVolume = readVolume(deviceID: deviceID, element: element)
        }

        // Install volume change listener
        installVolumeListener(deviceID: deviceID, element: element)
    }

    private func volumeElement(for deviceID: AudioDeviceID) -> AudioObjectPropertyElement {
        if Self.supportsVolumeOnElement(deviceID, element: kAudioObjectPropertyElementMain) {
            return kAudioObjectPropertyElementMain
        }
        return 1
    }

    private func readVolume(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr else {
            return 0
        }
        return volume
    }

    // MARK: - CoreAudio listeners

    private func installDeviceListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshDevices()
            }
        }
        deviceListListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address,
            DispatchQueue.main, block
        )
    }

    private func installDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring, self.monitoringDeviceUID == nil else { return }
                self.startMonitoring(deviceUID: nil)
            }
        }
        defaultDeviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address,
            DispatchQueue.main, block
        )
    }


    private func installVolumeListener(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isUpdatingVolume else { return }
                self.inputVolume = self.readVolume(
                    deviceID: self.monitoredDeviceID,
                    element: self.volumeListenerElement
                )
            }
        }
        volumeListenerBlock = block
        volumeListenerDeviceID = deviceID
        volumeListenerElement = element
        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
    }

    private func removeVolumeListener() {
        guard let block = volumeListenerBlock, volumeListenerDeviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: volumeListenerElement
        )
        AudioObjectRemovePropertyListenerBlock(volumeListenerDeviceID, &address, DispatchQueue.main, block)
        volumeListenerBlock = nil
        volumeListenerDeviceID = kAudioObjectUnknown
    }

    // MARK: - AUHAL audio unit (level metering)

    private func startEngineIfAvailable(deviceID: AudioDeviceID?) {
        guard !Self.isAudioInputInUse else {
            logger.info("Audio input in use by another component, skipping level monitoring")
            return
        }

        let effectiveDeviceID = deviceID ?? Self.defaultInputDeviceID() ?? kAudioObjectUnknown
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
        Self.isAudioInputInUse = true
        Self.activeMonitoringInstance = self
        logger.info("Level monitoring AUHAL started")
    }

    private func stopEngine() {
        guard let unit = monitoringAudioUnit else { return }
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        monitoringAudioUnit = nil
        deallocateBufferList()
        Self.isAudioInputInUse = false
        Self.activeMonitoringInstance = nil
        inputLevel = 0
        logger.info("Level monitoring AUHAL stopped")
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

        let manager = Unmanaged<AudioDeviceManager>.fromOpaque(inRefCon).takeUnretainedValue()
        guard let audioUnit = manager.monitoringAudioUnit,
              let abl = manager.monitoringBufferList else {
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
        guard now - manager.lastLevelUpdate >= .milliseconds(50) else { return noErr }
        manager.lastLevelUpdate = now

        Task { @MainActor [weak manager] in
            manager?.inputLevel = normalized
        }

        return noErr
    }
}
