import CoreAudio
import Foundation
import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct OutputVolumeDuckerTests {
  private final class CoreAudioSpy: @unchecked Sendable {
    var defaultOutputDeviceID: AudioDeviceID?
    var elements: [AudioDeviceID: AudioObjectPropertyElement] = [:]
    var volumes: [AudioDeviceID: Float] = [:]
    var writes: [(volume: Float, deviceID: AudioDeviceID, element: AudioObjectPropertyElement)] = []
    var addedListeners: [OutputVolumeDuckerListenerRegistration] = []
    var removedListeners: [OutputVolumeDuckerListenerRegistration] = []

    func makeOperations() -> OutputVolumeDuckerCoreAudio {
      OutputVolumeDuckerCoreAudio(
        defaultOutputDeviceID: { self.defaultOutputDeviceID },
        outputVolumeElement: { self.elements[$0] },
        readOutputVolume: { deviceID, _ in self.volumes[deviceID] },
        setOutputVolume: { volume, deviceID, element in
          self.writes.append((volume, deviceID, element))
          self.volumes[deviceID] = volume
        },
        addPropertyListener: { self.addedListeners.append($0) },
        removePropertyListener: { self.removedListeners.append($0) }
      )
    }
  }

  private func makeSettings(enabled: Bool = false, level: Float = 0.05) -> VolumeDuckingSettings {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = VolumeDuckingSettings(defaults: defaults)
    settings.isVolumeDuckingEnabled = enabled
    settings.volumeDuckingLevel = level
    return settings
  }

  @Test func disabledDuckDoesNothing() {
    let settings = makeSettings(enabled: false)
    let ducker = OutputVolumeDucker(settings: settings)
    ducker.duck()
    #expect(ducker.isDucked == false)
  }

  @Test func restoreWhenNotDuckedDoesNothing() {
    let settings = makeSettings(enabled: true)
    let ducker = OutputVolumeDucker(settings: settings)
    ducker.restore()
    #expect(ducker.isDucked == false)
  }

  @Test func enabledDuckUsesTheLowerOfCurrentVolumeAndLevel() {
    let settings = makeSettings(enabled: true, level: 0.5)
    let coreAudio = CoreAudioSpy()
    coreAudio.defaultOutputDeviceID = 1
    coreAudio.elements[1] = kAudioObjectPropertyElementMain
    coreAudio.volumes[1] = 0.25
    let ducker = OutputVolumeDucker(settings: settings, coreAudio: coreAudio.makeOperations())

    ducker.duck()

    #expect(ducker.isDucked == true)
    #expect(coreAudio.writes.map(\.volume) == [])

    ducker.restore()

    #expect(ducker.isDucked == false)
    #expect(coreAudio.writes.map(\.volume) == [])
  }

  @Test func outputDeviceChangeRestoresOldDeviceAndDucksNewDevice() {
    let settings = makeSettings(enabled: true, level: 0.3)
    let coreAudio = CoreAudioSpy()
    coreAudio.defaultOutputDeviceID = 1
    coreAudio.elements[1] = kAudioObjectPropertyElementMain
    coreAudio.elements[2] = 1
    coreAudio.volumes[1] = 0.8
    coreAudio.volumes[2] = 0.6
    let ducker = OutputVolumeDucker(settings: settings, coreAudio: coreAudio.makeOperations())

    ducker.duck()

    coreAudio.defaultOutputDeviceID = 2
    ducker.handleOutputDeviceChanged()

    #expect(ducker.isDucked == true)
    #expect(coreAudio.writes.count == 3)
    #expect(coreAudio.writes[0].volume == 0.3)
    #expect(coreAudio.writes[0].deviceID == 1)
    #expect(coreAudio.writes[0].element == kAudioObjectPropertyElementMain)
    #expect(coreAudio.writes[1].volume == 0.8)
    #expect(coreAudio.writes[1].deviceID == 1)
    #expect(coreAudio.writes[1].element == kAudioObjectPropertyElementMain)
    #expect(coreAudio.writes[2].volume == 0.3)
    #expect(coreAudio.writes[2].deviceID == 2)
    #expect(coreAudio.writes[2].element == 1)

    ducker.restore()

    #expect(ducker.isDucked == false)
    #expect(coreAudio.writes.last?.volume == 0.6)
    #expect(coreAudio.writes.last?.deviceID == 2)
    #expect(coreAudio.writes.last?.element == 1)
  }

  @Test func listenerIsInstalledOnceAcrossDeviceChangesAndRemovedOnRestore() {
    let settings = makeSettings(enabled: true, level: 0.3)
    let coreAudio = CoreAudioSpy()
    coreAudio.defaultOutputDeviceID = 1
    coreAudio.elements[1] = kAudioObjectPropertyElementMain
    coreAudio.elements[2] = kAudioObjectPropertyElementMain
    coreAudio.volumes[1] = 0.8
    coreAudio.volumes[2] = 0.6
    let ducker = OutputVolumeDucker(settings: settings, coreAudio: coreAudio.makeOperations())

    ducker.duck()
    let listener = try! #require(coreAudio.addedListeners.first)

    coreAudio.defaultOutputDeviceID = 2
    ducker.handleOutputDeviceChanged()

    #expect(coreAudio.addedListeners.count == 1)
    #expect(listener.objectID == AudioObjectID(kAudioObjectSystemObject))
    #expect(listener.address.mSelector == kAudioHardwarePropertyDefaultOutputDevice)
    #expect(listener.address.mScope == kAudioObjectPropertyScopeGlobal)
    #expect(listener.address.mElement == kAudioObjectPropertyElementMain)
    #expect(listener.queue === DispatchQueue.main)

    ducker.restore()

    #expect(coreAudio.removedListeners.count == 1)
    #expect(coreAudio.removedListeners.first === listener)
  }

  @Test func repeatedDuckAndRestorePairsEachListenerRegistration() {
    let settings = makeSettings(enabled: true, level: 0.3)
    let coreAudio = CoreAudioSpy()
    coreAudio.defaultOutputDeviceID = 1
    coreAudio.elements[1] = kAudioObjectPropertyElementMain
    coreAudio.volumes[1] = 0.8
    let ducker = OutputVolumeDucker(settings: settings, coreAudio: coreAudio.makeOperations())

    ducker.duck()
    ducker.restore()
    ducker.duck()
    ducker.restore()

    #expect(coreAudio.addedListeners.count == 2)
    #expect(coreAudio.removedListeners.count == 2)
    #expect(coreAudio.addedListeners[0] === coreAudio.removedListeners[0])
    #expect(coreAudio.addedListeners[1] === coreAudio.removedListeners[1])
    #expect(coreAudio.addedListeners[0] !== coreAudio.addedListeners[1])
  }

  @Test func deinitRestoresVolumeAndRemovesListenerThroughInjectedCoreAudio() {
    let settings = makeSettings(enabled: true, level: 0.3)
    let coreAudio = CoreAudioSpy()
    coreAudio.defaultOutputDeviceID = 1
    coreAudio.elements[1] = kAudioObjectPropertyElementMain
    coreAudio.volumes[1] = 0.8
    weak var weakDucker: OutputVolumeDucker?

    do {
      let ducker = OutputVolumeDucker(settings: settings, coreAudio: coreAudio.makeOperations())
      weakDucker = ducker
      ducker.duck()
      #expect(coreAudio.volumes[1] == 0.3)
    }

    #expect(weakDucker == nil)
    #expect(coreAudio.volumes[1] == 0.8)
    #expect(coreAudio.addedListeners.count == 1)
    #expect(coreAudio.removedListeners.count == 1)
    #expect(coreAudio.addedListeners.first === coreAudio.removedListeners.first)
  }
}
