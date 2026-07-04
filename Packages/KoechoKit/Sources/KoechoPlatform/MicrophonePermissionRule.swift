import AVFoundation

enum MicrophonePermissionRule {
  enum Action: Equatable {
    case proceed
    case requestAccess
    case deny
  }

  static func action(for status: AVAuthorizationStatus) -> Action {
    switch status {
    case .authorized:
      return .proceed
    case .notDetermined:
      return .requestAccess
    case .denied, .restricted:
      return .deny
    @unknown default:
      return .proceed
    }
  }
}
