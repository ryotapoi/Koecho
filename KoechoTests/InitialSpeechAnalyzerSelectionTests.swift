import Foundation
import KoechoCore
import SwiftUI
import Testing

@testable import Koecho

@MainActor
struct InitialSpeechAnalyzerSelectionTests {
  @Test(arguments: ["en-US", String?.none])
  func unchangedSelectionAppliesOnlyCorrection(_ correction: String?) async throws {
    let suiteName = "initial-speech-selection-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("en_US", forKey: "speechAnalyzerLocale")
    let settings = VoiceInputSettings(defaults: defaults)
    let selection = Binding(
      get: { settings.speechAnalyzerLocale },
      set: { settings.speechAnalyzerLocale = $0 }
    )

    await loadInitialSpeechAnalyzerSelection(selection: selection) { initialSelection in
      #expect(initialSelection == "en_US")
      return correction
    }

    #expect(selection.wrappedValue == (correction ?? "en_US"))
    #expect(VoiceInputSettings(defaults: defaults).speechAnalyzerLocale == selection.wrappedValue)
  }

  @Test(arguments: [false, true])
  func delayedCorrectionDoesNotOverwriteChangedOrCancelledSelection(
    cancel: Bool
  ) async throws {
    let suiteName = "delayed-speech-selection-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("en_US", forKey: "speechAnalyzerLocale")
    let settings = VoiceInputSettings(defaults: defaults)
    let selection = Binding(
      get: { settings.speechAnalyzerLocale },
      set: { settings.speechAnalyzerLocale = $0 }
    )
    var result: CheckedContinuation<String?, Never>?
    var loadTask: Task<Void, Never>?
    await withCheckedContinuation { started in
      loadTask = Task {
        await loadInitialSpeechAnalyzerSelection(selection: selection) { initialSelection in
          #expect(initialSelection == "en_US")
          return await withCheckedContinuation { continuation in
            result = continuation
            started.resume()
          }
        }
      }
    }
    let task = try #require(loadTask)
    if cancel {
      task.cancel()
    } else {
      // This writes through the same Binding and persistence path as the Picker.
      selection.wrappedValue = "ja-JP"
    }
    let expected = cancel ? "en_US" : "ja-JP"
    result?.resume(returning: "en-US")
    await task.value

    #expect(selection.wrappedValue == expected)
    #expect(VoiceInputSettings(defaults: defaults).speechAnalyzerLocale == expected)
  }
}
