import Testing
@testable import KoechoPlatform

@MainActor
struct AudioDeviceManagerTests {
    @Test func enumerateInputDevicesDoesNotCrash() {
        let manager = AudioDeviceManager()
        _ = manager.inputDevices
    }
}
