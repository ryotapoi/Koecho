import KoechoCore

@MainActor
enum SpeechModelPreparation {
  static func ensureModelAvailable(
    localeKey: String,
    isVerified: (String) -> Bool,
    markVerified: (String) -> Void,
    installationRequest: () async throws -> (() async throws -> Void)?,
    updateStatus: (VoiceInputEngineStatus?) -> Void
  ) async -> VoiceInputEngineError? {
    guard !isVerified(localeKey) else { return nil }

    do {
      if let downloadAndInstall = try await installationRequest() {
        updateStatus(.downloadingModel)
        try await downloadAndInstall()
        updateStatus(nil)
      }
      markVerified(localeKey)
      return nil
    } catch {
      updateStatus(nil)
      return .modelDownloadFailed(description: error.localizedDescription)
    }
  }
}
