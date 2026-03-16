import AudioToolbox
import CoreAudio
import Observation
import os

@MainActor @Observable
public final class AudioDeviceManager {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "AudioDeviceManager")

    public private(set) var inputDevices: [AudioInputDevice] = []
    public var inputLevel: Float { levelMonitor.inputLevel }
    public private(set) var inputVolume: Float = 0
    public private(set) var isMonitoring: Bool = false
    public private(set) var monitoredDeviceSupportsVolume: Bool = false

    private let levelMonitor = AudioInputLevelMonitor()

    // MARK: - Private state

    private var monitoringDeviceUID: String?
    private var monitoredDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isUpdatingVolume = false

    // CoreAudio listener blocks (retained for removal in deinit).
    @ObservationIgnored private nonisolated(unsafe) var deviceListListenerBlock: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private nonisolated(unsafe) var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private nonisolated(unsafe) var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private nonisolated(unsafe) var volumeListenerDeviceID: AudioDeviceID = kAudioObjectUnknown
    @ObservationIgnored private nonisolated(unsafe) var volumeListenerElement: AudioObjectPropertyElement = kAudioObjectPropertyElementMain

    // MARK: - Init / Deinit

    public init() {
        refreshDevices()
        installDeviceListListener()
        installDefaultDeviceListener()
    }

    deinit {
        // deinit is nonisolated, so access nonisolated(unsafe) properties directly
        // and call CoreAudio C functions (which are safe from any thread).

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

    public func refreshDevices() {
        inputDevices = AudioDeviceListing.enumerateInputDevices()
    }

    public func startMonitoring(deviceUID: String?) {
        stopMonitoring()

        // Resolve effective device ID.
        // If a specific UID is given but not found, fall back to system default
        // and clear monitoringDeviceUID so default device changes are tracked.
        var effectiveUID = deviceUID
        var deviceID: AudioDeviceID?
        if let uid = deviceUID {
            deviceID = AudioDeviceListing.resolveDeviceID(forUID: uid)
            if deviceID == nil {
                logger.warning("Device UID '\(uid, privacy: .public)' not found, falling back to system default")
                effectiveUID = nil
            }
        }
        if deviceID == nil {
            deviceID = AudioDeviceListing.defaultInputDeviceID()
        }

        guard let deviceID else {
            logger.warning("No input device available for monitoring")
            return
        }

        monitoringDeviceUID = effectiveUID
        monitoredDeviceID = deviceID
        setupVolumeMonitoring(for: deviceID)
        levelMonitor.start(deviceID: effectiveUID != nil ? deviceID : nil)
        isMonitoring = true
    }

    public func stopMonitoring() {
        levelMonitor.stop()
        removeVolumeListener()
        monitoredDeviceID = kAudioObjectUnknown
        monitoredDeviceSupportsVolume = false
        inputVolume = 0
        isMonitoring = false
    }

    public func setInputVolume(_ volume: Float) {
        guard monitoredDeviceID != kAudioObjectUnknown else { return }
        let clamped = max(0, min(1, volume))

        let element = volumeElement(for: monitoredDeviceID)
        guard element != kAudioObjectPropertyElementMain || AudioDeviceListing.supportsVolumeOnElement(monitoredDeviceID, element: kAudioObjectPropertyElementMain) else { return }

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

    // MARK: - Volume monitoring

    private func setupVolumeMonitoring(for deviceID: AudioDeviceID) {
        removeVolumeListener()

        let element = volumeElement(for: deviceID)
        monitoredDeviceSupportsVolume = AudioDeviceListing.supportsVolumeControl(deviceID)

        // Read current volume
        if monitoredDeviceSupportsVolume {
            inputVolume = readVolume(deviceID: deviceID, element: element)
        }

        // Install volume change listener
        installVolumeListener(deviceID: deviceID, element: element)
    }

    private func volumeElement(for deviceID: AudioDeviceID) -> AudioObjectPropertyElement {
        if AudioDeviceListing.supportsVolumeOnElement(deviceID, element: kAudioObjectPropertyElementMain) {
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
}
