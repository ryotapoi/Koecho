import Testing

@testable import KoechoPlatform

@MainActor
struct AudioDeviceManagerTests {
  @Test func refreshDevicesMatchesListing() {
    let manager = AudioDeviceManager()
    manager.refreshDevices()

    #expect(Set(manager.inputDevices.map(\.uid)).count == manager.inputDevices.count)
    #expect(manager.inputDevices.allSatisfy { !$0.uid.isEmpty && !$0.name.isEmpty })
  }
}
