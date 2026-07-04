import CoreAudio
import Testing

@testable import KoechoPlatform

struct AudioDeviceSelectionTests {
  @Test func monitoringTargetUsesResolvedDeviceWhenUIDResolves() {
    let target = AudioDeviceSelection.monitoringTarget(
      requestedUID: "external-mic",
      resolvedID: 42,
      systemDefaultID: 7
    )

    #expect(target == AudioDeviceSelection.MonitoringTarget(
      effectiveUID: "external-mic",
      deviceID: 42
    ))
  }

  @Test func monitoringTargetFallsBackToDefaultWhenUIDDoesNotResolve() {
    let target = AudioDeviceSelection.monitoringTarget(
      requestedUID: "missing-mic",
      resolvedID: nil,
      systemDefaultID: 7
    )

    #expect(target == AudioDeviceSelection.MonitoringTarget(
      effectiveUID: nil,
      deviceID: 7
    ))
  }

  @Test func monitoringTargetUsesDefaultWhenUIDIsNotRequested() {
    let target = AudioDeviceSelection.monitoringTarget(
      requestedUID: nil,
      resolvedID: nil,
      systemDefaultID: 7
    )

    #expect(target == AudioDeviceSelection.MonitoringTarget(
      effectiveUID: nil,
      deviceID: 7
    ))
  }

  @Test func monitoringTargetReturnsNilWhenNoDeviceIsAvailable() {
    let target = AudioDeviceSelection.monitoringTarget(
      requestedUID: nil,
      resolvedID: nil,
      systemDefaultID: nil
    )

    #expect(target == nil)
  }

  @Test func explicitDeviceIDReturnsDeviceIDOnlyForEffectiveUID() {
    let explicitTarget = AudioDeviceSelection.MonitoringTarget(
      effectiveUID: "external-mic",
      deviceID: 42
    )
    let defaultTarget = AudioDeviceSelection.MonitoringTarget(
      effectiveUID: nil,
      deviceID: 7
    )

    #expect(explicitTarget.explicitDeviceID == 42)
    #expect(defaultTarget.explicitDeviceID == nil)
  }

  @Test func engineDeviceIDUsesResolvedDeviceWhenUIDResolvesAndAudioUnitExists() {
    let deviceID = AudioDeviceSelection.engineDeviceID(
      requestedUID: "external-mic",
      resolvedID: 42,
      hasAudioUnit: true
    )

    #expect(deviceID == 42)
  }

  @Test func engineDeviceIDKeepsDefaultWhenUIDIsNotRequested() {
    let deviceID = AudioDeviceSelection.engineDeviceID(
      requestedUID: nil,
      resolvedID: 42,
      hasAudioUnit: true
    )

    #expect(deviceID == nil)
  }

  @Test func engineDeviceIDKeepsDefaultWhenUIDDoesNotResolve() {
    let deviceID = AudioDeviceSelection.engineDeviceID(
      requestedUID: "missing-mic",
      resolvedID: nil,
      hasAudioUnit: true
    )

    #expect(deviceID == nil)
  }

  @Test func engineDeviceIDKeepsDefaultWhenAudioUnitIsUnavailable() {
    let deviceID = AudioDeviceSelection.engineDeviceID(
      requestedUID: "external-mic",
      resolvedID: 42,
      hasAudioUnit: false
    )

    #expect(deviceID == nil)
  }

  @Test func volumeElementUsesMainElementWhenSupported() {
    let element = AudioDeviceSelection.volumeElement(supportsMainElement: true)

    #expect(element == kAudioObjectPropertyElementMain)
  }

  @Test func volumeElementUsesFirstChannelWhenMainElementIsUnsupported() {
    let element = AudioDeviceSelection.volumeElement(supportsMainElement: false)

    #expect(element == 1)
  }

  @Test func clampedVolumeConstrainsValuesToUnitRange() {
    #expect(AudioDeviceSelection.clampedVolume(-0.5) == 0)
    #expect(AudioDeviceSelection.clampedVolume(0) == 0)
    #expect(AudioDeviceSelection.clampedVolume(0.5) == 0.5)
    #expect(AudioDeviceSelection.clampedVolume(1) == 1)
    #expect(AudioDeviceSelection.clampedVolume(1.5) == 1)
  }
}
