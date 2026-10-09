import AudioToolbox
import CoreAudio
import KoechoCore
import Observation
import os

@MainActor @Observable
public final class AudioDeviceManager {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "AudioDeviceManager")

  public private(set) var inputDevices: [AudioInputDevice] = []
  public var inputLevel: Float { levelMonitor.inputLevel }
  public private(set) var inputVolume: Float = 0
  public var isMonitoring: Bool { monitoringState.target != nil }
  public private(set) var monitoredDeviceSupportsVolume: Bool = false

  private let levelMonitor = AudioInputLevelMonitor()

  // MARK: - Private state

  private var monitoringState = AudioDeviceSelection.MonitoringState()
  private var monitoredDeviceID: AudioDeviceID {
    monitoringState.target?.deviceID ?? kAudioObjectUnknown
  }
  private var isUpdatingVolume = false

  // CoreAudio listener blocks (retained for removal in deinit).
  @ObservationIgnored private var deviceListListenerBlock:
    AudioObjectPropertyListenerBlock?
  @ObservationIgnored private var defaultDeviceListenerBlock:
    AudioObjectPropertyListenerBlock?
  @ObservationIgnored private var volumeListenerBlock:
    AudioObjectPropertyListenerBlock?
  @ObservationIgnored private var volumeListenerDeviceID: AudioDeviceID =
    kAudioObjectUnknown
  @ObservationIgnored private var volumeListenerElement:
    AudioObjectPropertyElement = kAudioObjectPropertyElementMain

  // MARK: - Init / Deinit

  public init() {
    refreshDevices()
    installDeviceListListener()
    installDefaultDeviceListener()
  }

  isolated deinit {
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
    removeVolumeListener()
  }

  // MARK: - Public API

  public func refreshDevices() {
    inputDevices = AudioDeviceListing.enumerateInputDevices()
    refreshMonitoringTarget()
  }

  public func startMonitoring(deviceUID: String?, monitorInputLevel: Bool = true) {
    stopMonitoring()
    monitoringState.start(requestedUID: deviceUID, monitorInputLevel: monitorInputLevel)
    refreshMonitoringTarget()
    if monitoringState.target == nil {
      logger.warning("No input device available for monitoring")
    }
  }

  private func refreshMonitoringTarget() {
    guard monitoringState.isRequested else { return }
    let resolvedID = monitoringState.requestedUID.flatMap(
      AudioDeviceListing.resolveDeviceID(forUID:))
    guard monitoringState.refresh(
      resolvedID: resolvedID,
      systemDefaultID: AudioDeviceListing.defaultInputDeviceID()
    ) else { return }

    tearDownMonitoringTarget()
    guard let target = monitoringState.target else { return }
    if let uid = monitoringState.requestedUID, target.effectiveUID == nil {
      logger.warning(
        "Device UID '\(uid, privacy: .public)' not found, falling back to system default")
    }
    setupVolumeMonitoring(for: target.deviceID)
    if monitoringState.isInputLevelEnabled {
      levelMonitor.start(deviceID: target.explicitDeviceID)
    }
  }

  public func setInputLevelMonitoring(_ enabled: Bool) {
    monitoringState.isInputLevelEnabled = enabled

    guard isMonitoring else { return }
    if enabled {
      levelMonitor.start(deviceID: monitoringState.target?.explicitDeviceID)
    } else {
      levelMonitor.stop()
    }
  }

  public func stopMonitoring() {
    monitoringState.stop()
    tearDownMonitoringTarget()
  }

  private func tearDownMonitoringTarget() {
    levelMonitor.stop()
    removeVolumeListener()
    monitoredDeviceSupportsVolume = false
    inputVolume = 0
  }

  public func setInputVolume(_ volume: Float) {
    guard monitoredDeviceID != kAudioObjectUnknown else { return }
    let clamped = AudioDeviceSelection.clampedVolume(volume)

    let element = volumeElement(for: monitoredDeviceID)

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
    AudioDeviceSelection.volumeElement(
      supportsMainElement: AudioDeviceListing.supportsVolumeOnElement(
        deviceID, element: kAudioObjectPropertyElementMain)
    )
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
        self?.refreshMonitoringTarget()
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
    guard let block = volumeListenerBlock, volumeListenerDeviceID != kAudioObjectUnknown else {
      return
    }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioObjectPropertyScopeInput,
      mElement: volumeListenerElement
    )
    AudioObjectRemovePropertyListenerBlock(
      volumeListenerDeviceID, &address, DispatchQueue.main, block)
    volumeListenerBlock = nil
    volumeListenerDeviceID = kAudioObjectUnknown
  }
}
