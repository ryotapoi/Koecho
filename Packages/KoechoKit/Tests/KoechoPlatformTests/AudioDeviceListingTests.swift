import Testing

@testable import KoechoPlatform

@MainActor
struct AudioDeviceListingTests {
  @Test func enumerateInputDevicesReturnsUsableDeviceMetadata() {
    let devices = AudioDeviceListing.enumerateInputDevices()

    #expect(Set(devices.map(\.uid)).count == devices.count)
    #expect(devices.allSatisfy { !$0.uid.isEmpty && !$0.name.isEmpty })
  }

  @Test func resolveDeviceIDForInvalidUID() {
    let result = AudioDeviceListing.resolveDeviceID(forUID: "nonexistent-device-uid-12345")
    #expect(result == nil)
  }

  @Test func listedDeviceUIDsResolveToTheirDeviceIDs() {
    let devices = AudioDeviceListing.enumerateInputDevices()

    for device in devices {
      #expect(AudioDeviceListing.resolveDeviceID(forUID: device.uid) == device.audioDeviceID)
    }
  }
}
