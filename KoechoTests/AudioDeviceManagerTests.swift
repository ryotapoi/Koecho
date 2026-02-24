import Testing
@testable import Koecho

@MainActor
struct AudioDeviceManagerTests {
    @Test func enumerateInputDevicesDoesNotCrash() {
        let manager = AudioDeviceManager()
        // Should return an array (possibly empty in CI) without crashing
        _ = manager.inputDevices
    }

    @Test func resolveDeviceIDForInvalidUID() {
        let result = AudioDeviceManager.resolveDeviceID(forUID: "nonexistent-device-uid-12345")
        #expect(result == nil)
    }

    @Test func defaultInputDeviceID() {
        // Should not crash; result is environment-dependent
        _ = AudioDeviceManager.defaultInputDeviceID()
    }

    @Test func acquireReleaseAudioInput() {
        #expect(AudioDeviceManager.isAudioInputInUse == false)

        AudioDeviceManager.acquireAudioInput()
        #expect(AudioDeviceManager.isAudioInputInUse == true)

        AudioDeviceManager.releaseAudioInput()
        #expect(AudioDeviceManager.isAudioInputInUse == false)
    }
}
