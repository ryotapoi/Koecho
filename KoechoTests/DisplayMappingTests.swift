import AppKit
import Foundation
import KoechoCore
import KoechoPlatform
import Testing

@testable import Koecho

@MainActor
@Suite struct DisplayMappingTests {
  private enum FallbackPasteError: Error {
    case fallback
  }

  @Test func voiceInputErrorDisplayMessagesCoverAllCases() {
    let appState = makeTestAppState()
    let coordinator = makeTestVoiceCoordinator(
      appState: appState,
      makeEngine: { MockVoiceInputEngine() }
    )

    let cases: [(VoiceInputEngineError, String)] = [
      (
        .microphoneAccessDenied,
        String(
          localized:
            "Microphone access denied. Open System Settings > Privacy & Security > Microphone.")
      ),
      (
        .modelDownloadFailed(description: "offline"),
        String(localized: "Failed to download speech model: offline")
      ),
      (
        .noAudioInputDevice,
        String(localized: "No audio input device available.")
      ),
      (
        .noCompatibleAudioFormat,
        String(localized: "No compatible audio format available.")
      ),
      (
        .audioFormatConversionNotSupported,
        String(localized: "Audio format conversion not supported.")
      ),
      (
        .audioEngineStartFailed(description: "busy"),
        String(localized: "Failed to start audio engine: busy")
      ),
      (
        .recognitionError(description: "timed out"),
        String(localized: "Speech recognition error: timed out")
      ),
    ]

    for (error, expectedMessage) in cases {
      coordinator.voiceInput(didEncounterError: error)

      #expect(appState.errorMessage == expectedMessage)
    }
  }

  @Test func voiceInputStatusDisplayMessagesCoverAllCases() {
    let appState = makeTestAppState()
    let coordinator = makeTestVoiceCoordinator(
      appState: appState,
      makeEngine: { MockVoiceInputEngine() }
    )

    let cases: [(VoiceInputEngineStatus, String)] = [
      (
        .requestingMicrophoneAccess,
        String(localized: "Requesting microphone access...")
      ),
      (
        .downloadingModel,
        String(localized: "Downloading speech model...")
      ),
    ]

    for (status, expectedMessage) in cases {
      coordinator.voiceInput(didUpdateStatus: status)

      #expect(appState.voiceEngineStatus == expectedMessage)
    }

    coordinator.voiceInput(didUpdateStatus: nil)

    #expect(appState.voiceEngineStatus == nil)
  }

  @Test func inputPanelControllerPasteErrorMessagesCoverAllCases() async {
    let cases: [(any Error, String)] = [
      (
        ClipboardPasterError.accessibilityNotTrusted,
        String(
          localized:
            "Accessibility permission required. Open System Settings > Privacy & Security > Accessibility."
        )
      ),
      (
        ClipboardPasterError.targetAppTerminated,
        String(localized: "Target application has been terminated.")
      ),
      (
        ClipboardPasterError.failedToCreateCGEvent,
        String(localized: "Failed to simulate paste keystroke.")
      ),
      (
        FallbackPasteError.fallback,
        String(describing: FallbackPasteError.fallback)
      ),
    ]

    for (error, expectedMessage) in cases {
      let paster = MockPaster()
      paster.errorToThrow = error
      let ctx = makeController(paster: paster)
      ctx.controller.showPanel()
      ctx.appState.inputText = "hello"
      ctx.appState.frontmostApplication = NSRunningApplication.current

      await ctx.controller.confirm()

      #expect(ctx.appState.errorMessage == expectedMessage)
      #expect(ctx.appState.isInputPanelVisible == true)
      #expect(paster.restoreClipboardCallCount == 1)
    }
  }

  @Test func hotkeyKeyChoiceAllChoicesAreExhaustiveAndOrdered() {
    #expect(
      HotkeyKeyChoice.allChoices
        == [
          HotkeyKeyChoice(modifierKey: .command, side: .left),
          HotkeyKeyChoice(modifierKey: .command, side: .right),
          HotkeyKeyChoice(modifierKey: .shift, side: .left),
          HotkeyKeyChoice(modifierKey: .shift, side: .right),
          HotkeyKeyChoice(modifierKey: .option, side: .left),
          HotkeyKeyChoice(modifierKey: .option, side: .right),
          HotkeyKeyChoice(modifierKey: .control, side: .left),
          HotkeyKeyChoice(modifierKey: .control, side: .right),
          HotkeyKeyChoice(modifierKey: .fn, side: .left),
        ])
  }

  @Test func hotkeyDisplayNamesCoverAllCases() {
    let choiceCases: [(HotkeyKeyChoice, String)] = [
      (
        HotkeyKeyChoice(modifierKey: .command, side: .left),
        String(localized: "Command") + " (" + String(localized: "Left") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .command, side: .right),
        String(localized: "Command") + " (" + String(localized: "Right") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .shift, side: .left),
        String(localized: "Shift") + " (" + String(localized: "Left") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .shift, side: .right),
        String(localized: "Shift") + " (" + String(localized: "Right") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .option, side: .left),
        String(localized: "Option") + " (" + String(localized: "Left") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .option, side: .right),
        String(localized: "Option") + " (" + String(localized: "Right") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .control, side: .left),
        String(localized: "Control") + " (" + String(localized: "Left") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .control, side: .right),
        String(localized: "Control") + " (" + String(localized: "Right") + ")"
      ),
      (
        HotkeyKeyChoice(modifierKey: .fn, side: .left),
        String(localized: "Fn (Globe)")
      ),
      (
        HotkeyKeyChoice(modifierKey: .fn, side: .right),
        String(localized: "Fn (Globe)")
      ),
    ]

    for (choice, expectedDisplayName) in choiceCases {
      #expect(choice.displayName == expectedDisplayName)
    }

    let tapModeCases: [(TapMode, String)] = [
      (.singleToggle, String(localized: "Single Tap (toggle show/confirm)")),
      (.doubleTapToShow, String(localized: "Double Tap to show, Single Tap to confirm")),
    ]

    for (tapMode, expectedDisplayName) in tapModeCases {
      #expect(tapMode.displayName == expectedDisplayName)
    }
  }

  @Test func hotkeyModifierBadgesCoverAllCases() {
    let cases: [(ModifierKey, String)] = [
      (.command, "\u{2318}"),
      (.shift, "\u{21E7}"),
      (.option, "\u{2325}"),
      (.control, "\u{2303}"),
      (.fn, "fn"),
    ]

    for (modifierKey, expectedBadge) in cases {
      let config = HotkeyConfig(
        modifierKey: modifierKey,
        side: .left,
        tapMode: .singleToggle
      )

      #expect(config.modifierBadge == expectedBadge)
    }
  }
}
