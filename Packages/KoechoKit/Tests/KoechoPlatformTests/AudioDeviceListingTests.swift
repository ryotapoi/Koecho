import Testing

@testable import KoechoPlatform

@MainActor
struct AudioDeviceListingTests {
  @Test func resolveDeviceIDForInvalidUID() {
    let result = AudioDeviceListing.resolveDeviceID(forUID: "nonexistent-device-uid-12345")
    #expect(result == nil)
  }

}
