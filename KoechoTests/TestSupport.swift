import AppKit
import Foundation
import KoechoCore
import KoechoPlatform

@testable import Koecho

/// Creates an AppState backed by an isolated UserDefaults suite so tests
/// never read or write the real app preferences.
@MainActor
func makeTestAppState() -> AppState {
  let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
  return AppState(settings: Settings(defaults: defaults))
}

/// Creates a VoiceInputCoordinator wired to a fresh InputPanel, mirroring
/// the production wiring but with a mock engine by default.
@MainActor
func makeTestVoiceCoordinator(
  appState: AppState,
  makeEngine: @escaping () -> any VoiceInputEngine = { MockVoiceInputEngine() }
) -> VoiceInputCoordinator {
  let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))
  return VoiceInputCoordinator(
    appState: appState,
    makeEngine: makeEngine,
    panel: panel
  )
}

/// Writes an executable shell script to a temporary path and returns the path.
/// Callers are responsible for removing the file if they care about cleanup.
func makeScript(_ content: String) throws -> String {
  let dir = FileManager.default.temporaryDirectory
  let path = dir.appendingPathComponent("koecho-test-\(UUID().uuidString).sh").path
  try ("#!/bin/sh\n" + content).write(toFile: path, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes(
    [.posixPermissions: 0o755],
    ofItemAtPath: path
  )
  return path
}
