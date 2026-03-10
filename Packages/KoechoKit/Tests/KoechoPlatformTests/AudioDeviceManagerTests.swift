import KoechoCore
import Testing
@testable import KoechoPlatform

@MainActor
struct AudioDeviceManagerTests {
    @Test func enumerateInputDevicesDoesNotCrash() {
        let manager = AudioDeviceManager()
        _ = manager.inputDevices
    }

    @Test func resolveDeviceIDForInvalidUID() {
        let result = AudioDeviceManager.resolveDeviceID(forUID: "nonexistent-device-uid-12345")
        #expect(result == nil)
    }

    @Test func defaultInputDeviceID() {
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
