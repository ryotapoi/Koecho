import AudioToolbox
import CoreAudio
import KoechoCore
import Observation
import os

@MainActor
public protocol VolumeDucking {
    func duck()
    func restore()
}

@MainActor @Observable
public final class OutputVolumeDucker: VolumeDucking {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "OutputVolumeDucker")
    private let settings: VolumeDuckingSettings

    public private(set) var isDucked = false

    @ObservationIgnored private nonisolated(unsafe) var savedVolume: Float?
    @ObservationIgnored private nonisolated(unsafe) var duckedDeviceID: AudioDeviceID = kAudioObjectUnknown
    @ObservationIgnored private nonisolated(unsafe) var duckedElement: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    @ObservationIgnored private nonisolated(unsafe) var defaultOutputDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    public init(settings: VolumeDuckingSettings) {
        self.settings = settings
    }

    deinit {
        restoreVolumeSync()
        removeOutputDeviceListenerSync()
    }

    // MARK: - Public API

    public func duck() {
        guard settings.isVolumeDuckingEnabled, !isDucked else { return }

        guard let deviceID = defaultOutputDeviceID() else {
            logger.info("No default output device, skipping ducking")
            return
        }

        installOutputDeviceListener()

        guard let element = outputVolumeElement(for: deviceID) else {
            // Device doesn't support volume control; keep isDucked true so
            // the listener is active for device changes.
            isDucked = true
            logger.info("Output device does not support volume control, listener installed")
            return
        }

        guard let currentVolume = readOutputVolume(deviceID: deviceID, element: element) else {
            isDucked = true
            logger.warning("Failed to read output volume, listener installed")
            return
        }
        let target = min(currentVolume, settings.volumeDuckingLevel)

        if target < currentVolume {
            savedVolume = currentVolume
            duckedDeviceID = deviceID
            duckedElement = element
            setOutputVolume(target, deviceID: deviceID, element: element)
            logger.info("Ducked output volume from \(currentVolume, privacy: .public) to \(target, privacy: .public)")
        }

        isDucked = true
    }

    public func restore() {
        guard isDucked else { return }

        if let volume = savedVolume {
            setOutputVolume(volume, deviceID: duckedDeviceID, element: duckedElement)
            logger.info("Restored output volume to \(volume, privacy: .public)")
        }

        removeOutputDeviceListener()
        savedVolume = nil
        duckedDeviceID = kAudioObjectUnknown
        duckedElement = kAudioObjectPropertyElementMain
        isDucked = false
    }

    // MARK: - Device change handling

    private func handleOutputDeviceChanged() {
        guard isDucked else { return }

        // Restore old device volume (best-effort)
        if let volume = savedVolume {
            setOutputVolume(volume, deviceID: duckedDeviceID, element: duckedElement)
            logger.info("Restored old device volume to \(volume, privacy: .public)")
        }
        savedVolume = nil
        duckedDeviceID = kAudioObjectUnknown
        duckedElement = kAudioObjectPropertyElementMain

        // Duck on new device
        guard let newDeviceID = defaultOutputDeviceID() else {
            logger.info("No new default output device after change")
            return
        }

        guard let element = outputVolumeElement(for: newDeviceID) else {
            logger.info("New output device does not support volume control")
            return
        }

        guard let currentVolume = readOutputVolume(deviceID: newDeviceID, element: element) else {
            logger.warning("Failed to read new device volume")
            return
        }
        let target = min(currentVolume, settings.volumeDuckingLevel)

        if target < currentVolume {
            savedVolume = currentVolume
            duckedDeviceID = newDeviceID
            duckedElement = element
            setOutputVolume(target, deviceID: newDeviceID, element: element)
            logger.info("Ducked new device from \(currentVolume, privacy: .public) to \(target, privacy: .public)")
        }
    }

    // MARK: - CoreAudio helpers

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
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

    private func outputVolumeElement(for deviceID: AudioDeviceID) -> AudioObjectPropertyElement? {
        if supportsOutputVolumeOnElement(deviceID, element: kAudioObjectPropertyElementMain) {
            return kAudioObjectPropertyElementMain
        }
        if supportsOutputVolumeOnElement(deviceID, element: 1) {
            return 1
        }
        return nil
    }

    private func supportsOutputVolumeOnElement(_ deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr else { return false }
        return settable.boolValue
    }

    private func readOutputVolume(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: element
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr else {
            return nil
        }
        return volume
    }

    private func setOutputVolume(_ volume: Float, deviceID: AudioDeviceID, element: AudioObjectPropertyElement) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: element
        )
        var value = volume
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &value
        )
        if status != noErr {
            logger.warning("Failed to set output volume (status: \(status))")
        }
    }

    // MARK: - Listener management

    private func installOutputDeviceListener() {
        guard defaultOutputDeviceListenerBlock == nil else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleOutputDeviceChanged()
            }
        }
        defaultOutputDeviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address,
            DispatchQueue.main, block
        )
    }

    private func removeOutputDeviceListener() {
        removeOutputDeviceListenerSync()
    }

    // MARK: - Sync helpers for deinit

    private nonisolated func removeOutputDeviceListenerSync() {
        guard let block = defaultOutputDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address,
            DispatchQueue.main, block
        )
        defaultOutputDeviceListenerBlock = nil
    }

    private nonisolated func restoreVolumeSync() {
        guard let volume = savedVolume, duckedDeviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: duckedElement
        )
        var value = volume
        AudioObjectSetPropertyData(
            duckedDeviceID, &address, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &value
        )
    }
}
