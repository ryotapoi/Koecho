import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct SpeechModelPreparationTests {
  @Test func verifiedLocaleSkipsInstallationRequest() async {
    var installationRequestCalls = 0
    var markedLocales: [String] = []

    let error = await SpeechModelPreparation.ensureModelAvailable(
      localeKey: "ja_jp",
      isVerified: { _ in true },
      markVerified: { markedLocales.append($0) },
      installationRequest: {
        installationRequestCalls += 1
        return nil
      },
      updateStatus: { _ in }
    )

    #expect(error == nil)
    #expect(installationRequestCalls == 0)
    #expect(markedLocales.isEmpty)
  }

  @Test func missingRequestMarksVerifiedWithoutStatusUpdate() async {
    var installationRequestCalls = 0
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []

    let error = await SpeechModelPreparation.ensureModelAvailable(
      localeKey: "ja_jp",
      isVerified: { _ in false },
      markVerified: { markedLocales.append($0) },
      installationRequest: {
        installationRequestCalls += 1
        return nil
      },
      updateStatus: { statuses.append($0) }
    )

    #expect(error == nil)
    #expect(installationRequestCalls == 1)
    #expect(markedLocales == ["ja_jp"])
    #expect(statuses.isEmpty)
  }

  @Test func successfulDownloadUpdatesStatusAndMarksVerified() async {
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []
    var didDownload = false

    let error = await SpeechModelPreparation.ensureModelAvailable(
      localeKey: "ja_jp",
      isVerified: { _ in false },
      markVerified: { markedLocales.append($0) },
      installationRequest: {
        {
          didDownload = true
        }
      },
      updateStatus: { statuses.append($0) }
    )

    #expect(error == nil)
    #expect(didDownload)
    #expect(statuses == [.downloadingModel, nil])
    #expect(markedLocales == ["ja_jp"])
  }

  @Test func installationRequestFailureClearsStatusAndDoesNotMarkVerified() async {
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []

    let error = await SpeechModelPreparation.ensureModelAvailable(
      localeKey: "ja_jp",
      isVerified: { _ in false },
      markVerified: { markedLocales.append($0) },
      installationRequest: {
        throw TestModelError.failure
      },
      updateStatus: { statuses.append($0) }
    )

    #expect(error?.isModelDownloadFailed == true)
    #expect(statuses == [nil])
    #expect(markedLocales.isEmpty)
  }

  @Test func downloadFailureClearsStatusAndDoesNotMarkVerified() async {
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []

    let error = await SpeechModelPreparation.ensureModelAvailable(
      localeKey: "ja_jp",
      isVerified: { _ in false },
      markVerified: { markedLocales.append($0) },
      installationRequest: {
        {
          throw TestModelError.failure
        }
      },
      updateStatus: { statuses.append($0) }
    )

    #expect(error?.isModelDownloadFailed == true)
    #expect(statuses == [.downloadingModel, nil])
    #expect(markedLocales.isEmpty)
  }
}

private enum TestModelError: Error {
  case failure
}

private extension VoiceInputEngineError {
  var isModelDownloadFailed: Bool {
    if case .modelDownloadFailed = self { return true }
    return false
  }
}
