import Darwin
import Foundation
import KoechoCore
import os

/// Owns only the suite created by the actual hosted App startup, never injected fixtures.
nonisolated final class HostedTestDefaults: @unchecked Sendable {
  struct Record: Codable {
    let version: Int
    let launchID: String
    let suiteName: String
    let pid: Int32
    let started: String
    let command: String
    let runID: String?
    var appCleanup: Bool
  }

  static let launch: HostedTestDefaults = {
    do {
      let environment = ProcessInfo.processInfo.environment
      let directory = environment["KOECHO_HOSTED_DEFAULTS_DIRECTORY"].map {
        URL(fileURLWithPath: $0, isDirectory: true)
      } ?? FileManager.default.temporaryDirectory.appendingPathComponent("koecho-hosted-defaults")
      let owner = try HostedTestDefaults(directory: directory, runID: environment["KOECHO_HOSTED_DEFAULTS_RUN"])
      atexit { HostedTestDefaults.launch.cleanupAtExit() }
      return owner
    } catch {
      // Do not construct Settings or fall back to normal preferences without ownership.
      fatalError("Cannot record hosted test defaults ownership: \(error)")
    }
  }()

  let defaults: UserDefaults
  let recordURL: URL
  let record: Record

  init(directory: URL, runID: String? = nil) throws {
    let launchID = UUID().uuidString
    let suiteName = "com.ryotapoi.Koecho.hosted-tests-\(launchID)"
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-p", String(getpid()), "-o", "lstart=", "-o", "command="]
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let fields = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isWhitespace)
    guard process.terminationStatus == 0, fields.count > 5 else {
      throw CocoaError(.fileReadUnknown)
    }
    record = Record(version: 1, launchID: launchID, suiteName: suiteName, pid: getpid(),
                    started: fields.prefix(5).joined(separator: " "),
                    command: fields.dropFirst(5).joined(separator: " "),
                    runID: runID, appCleanup: false)
    recordURL = directory.appendingPathComponent("\(launchID).json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode(record).write(to: recordURL, options: .atomic)
    defaults = UserDefaults(suiteName: suiteName)!
  }

  @discardableResult
  func cleanup() throws -> Bool {
    defaults.removePersistentDomain(forName: record.suiteName)
    guard defaults.synchronize(),
          (defaults.persistentDomain(forName: record.suiteName) ?? [:]).isEmpty else {
      return false
    }
    // Foundation leaves a zero-key plist behind after removePersistentDomain.
    let plist = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Preferences/\(record.suiteName).plist")
    if FileManager.default.fileExists(atPath: plist.path) {
      try FileManager.default.removeItem(at: plist)
    }
    var completed = record
    completed.appCleanup = true
    // Retain the exact ownership and outcome for post-exit verification and interrupted runs.
    try JSONEncoder().encode(completed).write(to: recordURL, options: .atomic)
    return true
  }

  private func cleanupAtExit() {
    do {
      if try !cleanup() { throw CocoaError(.fileWriteUnknown) }
    } catch {
      Logger(subsystem: Logger.koechoSubsystem, category: "HostedTestDefaults")
        .error("Hosted defaults cleanup failed: \(error)")
    }
  }
}
