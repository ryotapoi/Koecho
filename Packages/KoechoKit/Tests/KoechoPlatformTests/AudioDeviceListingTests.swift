import Testing
@testable import KoechoPlatform

@MainActor
struct AudioDeviceListingTests {
    @Test func enumerateInputDevicesDoesNotCrash() {
        let devices = AudioDeviceListing.enumerateInputDevices()
        // Should return an array (possibly empty in CI, non-empty on real Mac)
        _ = devices
    }

    @Test func resolveDeviceIDForInvalidUID() {
        let result = AudioDeviceListing.resolveDeviceID(forUID: "nonexistent-device-uid-12345")
        #expect(result == nil)
    }

    @Test func defaultInputDeviceID() {
        _ = AudioDeviceListing.defaultInputDeviceID()
    }
}
