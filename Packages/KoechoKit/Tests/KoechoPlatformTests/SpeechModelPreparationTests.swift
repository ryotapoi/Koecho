import KoechoCore
import Testing

@testable import KoechoPlatform

@MainActor
struct SpeechModelPreparationTests {
  @Test func verifiedLocaleSkipsInstallationRequest() async throws {
    var installationRequestCalls = 0
    var markedLocales: [String] = []

    let error = try await SpeechModelPreparation.ensureModelAvailable(
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

  @Test func missingRequestMarksVerifiedWithoutStatusUpdate() async throws {
    var installationRequestCalls = 0
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []

    let error = try await SpeechModelPreparation.ensureModelAvailable(
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

  @Test func successfulDownloadUpdatesStatusAndMarksVerified() async throws {
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []
    var didDownload = false

    let error = try await SpeechModelPreparation.ensureModelAvailable(
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

  @Test func installationRequestFailureClearsStatusAndDoesNotMarkVerified() async throws {
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []

    let error = try await SpeechModelPreparation.ensureModelAvailable(
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

  @Test func downloadFailureClearsStatusAndDoesNotMarkVerified() async throws {
    var markedLocales: [String] = []
    var statuses: [VoiceInputEngineStatus?] = []

    let error = try await SpeechModelPreparation.ensureModelAvailable(
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

extension SpeechModelPreparationTests {
  @Test func cancelledCacheHitThrowsWithoutVerifyingOrReporting() async {
    let wait = SpeechPreparationSuspension<Bool>()
    var calls = 0
    let task = Task { @MainActor in
      _ = await wait.wait()
      do {
        _ = try await SpeechModelPreparation.ensureModelAvailable(
          localeKey: "ja_jp", isVerified: { _ in calls += 1; return true },
          markVerified: { _ in calls += 1 }, installationRequest: { calls += 1; return nil },
          updateStatus: { _ in calls += 1 }
        )
        Issue.record("Cancelled cache hit returned success")
      } catch {
        #expect(error is CancellationError)
      }
    }
    await wait.waitForArrival()
    task.cancel()
    wait.resume(returning: true)
    await task.value
    #expect(calls == 0)
  }

  @Test(arguments: [false, true], [false, true])
  func cancelledRequestOrDownloadCannotVerifyOrReportFailure(download: Bool, fail: Bool) async {
    let wait = SpeechPreparationSuspension<Bool>()
    var marks = 0
    var downloads = 0
    var statuses: [VoiceInputEngineStatus?] = []
    let task = Task { @MainActor in
      do {
        _ = try await SpeechModelPreparation.ensureModelAvailable(
          localeKey: "ja_jp", isVerified: { _ in false }, markVerified: { _ in marks += 1 },
          installationRequest: {
            if !download {
              _ = await wait.wait()
              if fail { throw TestModelError.failure }
            }
            return {
              downloads += 1
              if download {
                _ = await wait.wait()
                if fail { throw TestModelError.failure }
              }
            }
          },
          updateStatus: { statuses.append($0) }
        )
        Issue.record("Cancelled model preparation returned success")
      } catch {
        #expect(error is CancellationError)
      }
    }
    await wait.waitForArrival()
    task.cancel()
    wait.resume(returning: true)
    await task.value
    #expect(marks == 0)
    #expect(downloads == (download ? 1 : 0))
    #expect(statuses == (download ? [.downloadingModel] : []))
  }
}
