import CoreAudio

enum AudioDeviceSelection {
  struct MonitoringState {
    private(set) var isRequested = false
    private(set) var requestedUID: String?
    private(set) var target: MonitoringTarget?
    var isInputLevelEnabled = false

    mutating func start(requestedUID: String?, monitorInputLevel: Bool) {
      self.requestedUID = requestedUID
      isRequested = true
      isInputLevelEnabled = monitorInputLevel
    }

    // Keep the request even when fallback or no device is currently available.
    mutating func refresh(resolvedID: AudioDeviceID?, systemDefaultID: AudioDeviceID?) -> Bool {
      guard isRequested else { return false }
      let newTarget = monitoringTarget(
        requestedUID: requestedUID,
        resolvedID: resolvedID,
        systemDefaultID: systemDefaultID
      )
      guard newTarget != target else { return false }
      target = newTarget
      return true
    }

    mutating func stop() {
      self = MonitoringState()
    }
  }

  struct MonitoringTarget: Equatable {
    let effectiveUID: String?
    let deviceID: AudioDeviceID

    var explicitDeviceID: AudioDeviceID? {
      effectiveUID == nil ? nil : deviceID
    }
  }

  static func monitoringTarget(
    requestedUID: String?,
    resolvedID: AudioDeviceID?,
    systemDefaultID: AudioDeviceID?
  ) -> MonitoringTarget? {
    if let requestedUID, let resolvedID {
      return MonitoringTarget(effectiveUID: requestedUID, deviceID: resolvedID)
    }

    guard let systemDefaultID else { return nil }
    return MonitoringTarget(effectiveUID: nil, deviceID: systemDefaultID)
  }

  static func engineDeviceID(
    requestedUID: String?,
    resolvedID: AudioDeviceID?,
    hasAudioUnit: Bool
  ) -> AudioDeviceID? {
    guard requestedUID != nil, hasAudioUnit else { return nil }
    return resolvedID
  }

  static func volumeElement(
    supportsMainElement: Bool
  ) -> AudioObjectPropertyElement {
    supportsMainElement ? kAudioObjectPropertyElementMain : 1
  }

  static func clampedVolume(_ volume: Float) -> Float {
    min(1, max(0, volume))
  }
}
