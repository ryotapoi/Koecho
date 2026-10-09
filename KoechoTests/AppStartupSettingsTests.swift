import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
struct AppStartupSettingsTests {
  @Test func ownedHostedDefaultsCleanupPreservesOtherSuitesAndOwnership() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("koecho-owned-defaults-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let owner = try HostedTestDefaults(directory: directory, runID: "fixture-run")
    let other = try HostedTestDefaults(directory: directory, runID: "other-run")
    defer { try? owner.cleanup(); try? other.cleanup() }
    owner.defaults.set("owned", forKey: "sentinel")
    other.defaults.set("preserved", forKey: "sentinel")
    let record = try JSONDecoder().decode(HostedTestDefaults.Record.self, from: Data(contentsOf: owner.recordURL))
    #expect(record.suiteName == "com.ryotapoi.Koecho.hosted-tests-\(record.launchID)")
    #expect(record.runID == "fixture-run")
    #expect(record.pid == ProcessInfo.processInfo.processIdentifier)
    #expect(!record.started.isEmpty && !record.command.isEmpty)
    #expect(try owner.cleanup())
    #expect(owner.defaults.persistentDomain(forName: record.suiteName)?.isEmpty != false)
    let plist = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Preferences/\(record.suiteName).plist")
    #expect(!FileManager.default.fileExists(atPath: plist.path))
    #expect(other.defaults.string(forKey: "sentinel") == "preserved")
    #expect(try owner.cleanup())
    let completed = try JSONDecoder().decode(HostedTestDefaults.Record.self, from: Data(contentsOf: owner.recordURL))
    #expect(completed.appCleanup)
  }

  @Test func historyUsesRuntimeIdentityAndVerificationOperationsAreIsolated() throws {
    let support = FileManager.default.temporaryDirectory
      .appendingPathComponent("koecho-history-startup-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: support) }
    let suite = "koecho-history-startup-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = HistorySettings(defaults: defaults)
    let legacy = support.appendingPathComponent("com.ryotapoi.koecho")
    HistoryStore(directoryURL: legacy).add(text: "legacy", settings: settings)
    let normal = KoechoApp.makeInitialHistoryStore(
      isTesting: false, bundleIdentifier: "com.ryotapoi.Koecho", applicationSupportURL: support
    )
    #expect(normal.entries.map(\.text) == ["legacy"])
    let normalFile = support.appendingPathComponent("com.ryotapoi.Koecho/history.json")
    let normalData = try Data(contentsOf: normalFile)
    // Keep a legacy fixture even when the migration moved the original file.
    if !FileManager.default.fileExists(atPath: legacy.appendingPathComponent("history.json").path) {
      HistoryStore(directoryURL: legacy).add(text: "old fixture", settings: settings)
    }
    let legacyFile = legacy.appendingPathComponent("history.json")
    let legacyData = try Data(contentsOf: legacyFile)
    let verification = KoechoApp.makeInitialHistoryStore(
      isTesting: false, bundleIdentifier: "com.ryotapoi.Koecho.Verification",
      applicationSupportURL: support
    )
    #expect(verification.entries.isEmpty)
    verification.purge(maxCount: 1, retentionDays: 1)
    verification.add(text: "verification", settings: settings)
    let verificationFile = support.appendingPathComponent("com.ryotapoi.Koecho.Verification/history.json")
    #expect(FileManager.default.fileExists(atPath: verificationFile.path))
    verification.deleteEntry(id: try #require(verification.entries.first).id)
    verification.add(text: "clear", settings: settings)
    #expect(verification.clear())
    #expect(try Data(contentsOf: normalFile) == normalData)
    #expect(try Data(contentsOf: legacyFile) == legacyData)
    let mixedCase = KoechoApp.makeInitialHistoryStore(
      isTesting: false, bundleIdentifier: "Example.MixedCASE", applicationSupportURL: support
    )
    mixedCase.add(text: "case", settings: settings)
    #expect(FileManager.default.fileExists(atPath: support.appendingPathComponent("Example.MixedCASE/history.json").path))
  }

  @Test func hostedStartupIsolatesHistoryBeforeResolvingNormalStorage() throws {
    #expect(KoechoApp.isTesting)
    let testing = FileManager.default.temporaryDirectory
      .appendingPathComponent("koecho-hosted-history-fixture-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: testing) }
    var accessedNormalStorage = false
    func normalSupport() -> URL {
      accessedNormalStorage = true
      return URL(fileURLWithPath: "/unused")
    }
    let store = KoechoApp.makeInitialHistoryStore(
      applicationSupportURL: normalSupport(), testingDirectoryURL: testing
    )
    #expect(!accessedNormalStorage)
    #expect(store.entries.isEmpty)
    #expect(store.clear())
    #expect(FileManager.default.fileExists(atPath: testing.appendingPathComponent("history.json").path))
  }

  @Test func hostedStartupIsolatesSettingsBeforeNormalization() throws {
    #expect(KoechoApp.isTesting)
    let normalName = "koecho-startup-normal-\(UUID().uuidString)"
    let hostedName = "koecho-startup-hosted-\(UUID().uuidString)"
    let normal = try #require(UserDefaults(suiteName: normalName))
    let hosted = try #require(UserDefaults(suiteName: hostedName))
    defer {
      normal.removePersistentDomain(forName: normalName)
      hosted.removePersistentDomain(forName: hostedName)
    }
    let fixture: [String: Any] = [
      "scriptTimeout": "invalid-timeout",
      "voiceInputMode": "dictation",
      "voiceInputShortcut": Data([0xFF]),
      "audioInputDeviceUID": "normal-only-device",
    ]
    normal.setPersistentDomain(fixture, forName: normalName)
    var accessedNormalDefaults = false
    func normalDefaults() -> UserDefaults {
      accessedNormalDefaults = true
      return normal
    }

    // Use the same default test detection and construction as the App's @State.
    let state = KoechoApp.makeInitialAppState(
      normalDefaults: normalDefaults(), testingSuiteName: hostedName
    )
    #expect(!accessedNormalDefaults)
    #expect(state.settings.script.scriptTimeout == 30)
    #expect(state.settings.voiceInput.audioInputDeviceUID == nil)
    #expect(state.settings.loadFailures.isEmpty)
    #expect(hosted.string(forKey: "voiceInputMode") == "on")
    #expect(hosted.double(forKey: "scriptTimeout") == 30)
    #expect(hosted.data(forKey: "voiceInputShortcut") == Data())

    state.settings.script.scriptTimeout = 17
    state.settings.voiceInput.isVoiceInputEnabled = false
    #expect(hosted.double(forKey: "scriptTimeout") == 17)
    #expect(hosted.string(forKey: "voiceInputMode") == "off")
    let preserved = try #require(normal.persistentDomain(forName: normalName))
    #expect(NSDictionary(dictionary: preserved).isEqual(to: fixture))
    #expect(preserved["scriptTimeout"] is String)
    #expect(preserved["voiceInputMode"] is String)
    #expect(preserved["voiceInputShortcut"] is Data)
  }

  @Test func normalStartupRetainsSettingsAndNormalization() throws {
    let suiteName = "koecho-startup-normal-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.setPersistentDomain([
      "scriptTimeout": "invalid-timeout",
      "voiceInputMode": "dictation",
      "voiceInputShortcut": Data([0xFF]),
      "audioInputDeviceUID": "normal-only-device",
    ], forName: suiteName)

    let state = KoechoApp.makeInitialAppState(isTesting: false, normalDefaults: defaults)
    #expect(state.settings.voiceInput.audioInputDeviceUID == "normal-only-device")
    #expect(state.settings.voiceInput.isVoiceInputEnabled)
    #expect(state.settings.loadFailures == [.scriptTimeout, .voiceInputShortcut])
    #expect(defaults.double(forKey: "scriptTimeout") == 30)
    #expect(defaults.string(forKey: "voiceInputMode") == "on")
    #expect(defaults.data(forKey: "voiceInputShortcut") == Data())
    state.settings.script.scriptTimeout = 19
    #expect(defaults.double(forKey: "scriptTimeout") == 19)
  }
}
