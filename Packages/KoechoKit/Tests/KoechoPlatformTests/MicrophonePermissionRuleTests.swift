import AVFoundation
import Testing

@testable import KoechoPlatform

struct MicrophonePermissionRuleTests {
  @Test func authorizedProceeds() {
    #expect(MicrophonePermissionRule.action(for: .authorized) == .proceed)
  }

  @Test func notDeterminedRequestsAccess() {
    #expect(MicrophonePermissionRule.action(for: .notDetermined) == .requestAccess)
  }

  @Test func deniedDeniesAccess() {
    #expect(MicrophonePermissionRule.action(for: .denied) == .deny)
  }

  @Test func restrictedDeniesAccess() {
    #expect(MicrophonePermissionRule.action(for: .restricted) == .deny)
  }
}
