import KoechoCore

@MainActor
enum SpeechModelPreparation {
  static func ensureModelAvailable(
    localeKey: String,
    isVerified: (String) -> Bool,
    markVerified: (String) -> Void,
    installationRequest: () async throws -> (() async throws -> Void)?,
    updateStatus: (VoiceInputEngineStatus?) -> Void
  ) async throws -> VoiceInputEngineError? {
    try Task.checkCancellation()
    guard !isVerified(localeKey) else { return nil }

    do {
      let downloadAndInstall = try await installationRequest()
      try Task.checkCancellation()
      if let downloadAndInstall {
        updateStatus(.downloadingModel)
        try Task.checkCancellation()
        try await downloadAndInstall()
        try Task.checkCancellation()
        updateStatus(nil)
      }
      markVerified(localeKey)
      return nil
    } catch {
      try Task.checkCancellation()
      if error is CancellationError { throw error }
      updateStatus(nil)
      return .modelDownloadFailed(description: error.localizedDescription)
    }
  }
}
