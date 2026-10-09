import AppKit
import KoechoCore
import KoechoPlatform
import SwiftUI
import os

@MainActor
final class InputPanelController {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "InputPanelController")
  private let appState: AppState
  private let paster: any Pasting
  private let historyStore: HistoryStore
  private var isConfirming = false
  // Covers voice finalization and auto-run without blocking Escape cancellation.
  private var processingConfirmationID: UUID?
  private var textView: VoiceInputTextView?
  private(set) var panel: InputPanel
  private var replacementService: ReplacementService!
  private var scriptService: ScriptExecutionService!
  private(set) var shortcutScriptTask: Task<Void, Never>?
  private(set) var voiceShortcutTask: Task<Void, Never>?
  // Internal getter so tests can reach replay state directly instead of
  // production-unused forwarding properties on the controller.
  private(set) var voiceCoordinator: VoiceInputCoordinator!
  private var lifecycleManager: PanelLifecycleManager!

  init(
    appState: AppState,
    selectedTextReader: any SelectedTextReading,
    paster: any Pasting,
    makeScriptRunner: @escaping () -> ScriptRunner,
    makeEngine: (() -> any VoiceInputEngine)? = nil,
    historyStore: HistoryStore,
    ducker: any VolumeDucking
  ) {
    self.appState = appState
    self.paster = paster
    self.historyStore = historyStore

    self.panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240))

    self.lifecycleManager = PanelLifecycleManager(
      appState: appState,
      selectedTextReader: selectedTextReader,
      ducker: ducker,
      panel: panel
    )

    let engineFactory =
      makeEngine ?? { () -> any VoiceInputEngine in
        let locale = Locale(identifier: appState.settings.voiceInput.speechAnalyzerLocale)
        return SpeechAnalyzerEngine(
          locale: locale,
          deviceUID: appState.settings.voiceInput.audioInputDeviceUID
        )
      }

    self.voiceCoordinator = VoiceInputCoordinator(
      appState: appState,
      makeEngine: engineFactory
    )

    self.replacementService = ReplacementService(
      appState: appState,
      voiceCoordinator: voiceCoordinator
    )

    self.scriptService = ScriptExecutionService(
      appState: appState,
      makeScriptRunner: makeScriptRunner,
      voiceCoordinator: voiceCoordinator,
      isConfirming: { [weak self] in self?.isConfirming ?? false }
    )

    voiceCoordinator.onReplacementInput = { [weak self] in
      self?.replacementService.handleInput()
    }
    voiceCoordinator.onCursorAutoReplacement = { [weak self] in
      guard let self, self.appState.settings.replacement.isAutoReplacementEnabled else { return }
      self.replacementService.applyOrPreview()
    }

    configureContentView()
    configurePanelCallbacks()

    panel.setFrameAutosaveName("InputPanel")
    if UserDefaults.standard.string(forKey: "NSWindow Frame InputPanel") == nil {
      panel.center()
    }
    logger.info("InputPanelController initialized")
  }

  convenience init(appState: AppState, historyStore: HistoryStore) {
    self.init(
      appState: appState,
      selectedTextReader: SelectedTextReader(),
      paster: ClipboardPaster(),
      makeScriptRunner: { ScriptRunner(timeout: appState.settings.script.scriptTimeout) },
      historyStore: historyStore,
      ducker: OutputVolumeDucker(settings: appState.settings.volumeDucking)
    )
  }

  // MARK: - Panel lifecycle

  func showPanel() {
    if appState.isInputPanelVisible {
      logger.debug("Panel already visible, refocusing")
      panel.makeKeyAndOrderFront(nil)
      return
    }

    let voiceEnabled = appState.settings.voiceInput.isVoiceInputEnabled
    lifecycleManager.show(duckVolume: voiceEnabled)
    if voiceEnabled {
      voiceCoordinator.prepareForShow()
    } else { voiceCoordinator.resetState() }
    clearTextView(startEngine: voiceEnabled)

    logger.info("Panel shown, isKeyWindow: \(self.panel.isKeyWindow)")
  }

  func confirm() async {
    guard appState.isInputPanelVisible, processingConfirmationID == nil, !isConfirming,
      !appState.isRunningScript
    else { return }
    let confirmationID = UUID()
    processingConfirmationID = confirmationID
    defer {
      if processingConfirmationID == confirmationID { processingConfirmationID = nil }
    }
    appState.discardScriptUndo()

    let suspensionID: UUID?
    if appState.settings.script.autoRunScript != nil {
      textView?.commitMarkedTextIfNeeded()
      suspensionID = voiceCoordinator.suspendInput()
      appState.isRunningScript = true
    } else {
      suspensionID = nil
    }
    defer {
      if processingConfirmationID == confirmationID {
        appState.isRunningScript = false
        if let suspensionID { voiceCoordinator.finishSuspension(suspensionID, resume: false) }
      }
    }
    guard let rawText = await finalizeVoiceInput(confirmationID: confirmationID) else { return }
    let replacedText = appState.settings.replacement.isAutoReplacementEnabled
      ? replacementService.applyRules(to: rawText) : rawText
    let text = replacedText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      dismissAsEmptyConfirm()
      return
    }

    guard let preparedText = await applyAutoRunScript(to: text, confirmationID: confirmationID) else { return }
    guard processingConfirmationID == confirmationID else { return }
    await pasteAndRecord(preparedText)
  }

  /// Confirm phase 1: stop voice input and collect the finalized text,
  /// clearing the text view.
  private func finalizeVoiceInput(confirmationID: UUID) async -> String? {
    // Commit IME text before stopping voice input so finalization cannot discard it.
    textView?.commitMarkedTextIfNeeded()
    replacementService.clearPreviews()
    await voiceCoordinator.stopEngine()
    guard processingConfirmationID == confirmationID, appState.isInputPanelVisible else { return nil }
    voiceCoordinator.finalizeRemainingVolatile()

    let rawText: String
    if let textView {
      let tvString = textView.finalizedString
      rawText = tvString.isEmpty ? appState.inputText : tvString
    } else {
      rawText = appState.inputText
    }
    textView?.replaceText("")
    return rawText
  }

  /// Confirm phase 2 (empty result): treat the confirm as a cancel.
  private func dismissAsEmptyConfirm() {
    paster.restoreClipboard()
    resetStateAndHidePanel()
    logger.info("confirm() with empty text, treated as cancel")
  }

  /// Shared teardown: resets voice-input state, clears panel app state,
  /// and hides the panel.
  private func resetStateAndHidePanel() {
    voiceCoordinator.resetState()
    lifecycleManager.clearState()
    lifecycleManager.hide()
  }

  /// Confirm phase 3: run the configured auto-run script on `text`.
  /// Returns the text to paste, or nil when the confirm was cancelled
  /// mid-flight or the script failed (the error is surfaced here).
  private func applyAutoRunScript(to text: String, confirmationID: UUID) async -> String? {
    guard let autoScript = appState.settings.script.autoRunScript else { return text }
    guard appState.isInputPanelVisible else { return nil }

    appState.setInputText(text)
    textView?.replaceText(text)

    do {
      let transformed = try await scriptService.runAutoScript(autoScript, on: text)
      guard appState.isInputPanelVisible, processingConfirmationID == confirmationID else { return nil }
      return transformed
    } catch is CancellationError {
      return nil
    } catch {
      guard appState.isInputPanelVisible, processingConfirmationID == confirmationID else { return nil }
      appState.setInputText(text)
      textView?.replaceText(text)
      appState.errorMessage = scriptService.scriptErrorMessage(for: error, script: autoScript)
      return nil
    }
  }

  /// Confirm phase 4: hide the panel, paste into the target app, and
  /// record history. On paste failure the panel is restored with the
  /// text and an error message.
  private func pasteAndRecord(_ text: String) async {
    guard let targetApp = appState.frontmostApplication else {
      appState.errorMessage = String(localized: "No target application")
      return
    }

    isConfirming = true
    defer { isConfirming = false }

    resetStateAndHidePanel()

    do {
      try await paster.paste(
        text: text, to: targetApp, using: .general,
        pasteDelay: appState.settings.paste.pasteDelay)
      historyStore.add(text: text, settings: appState.settings.history)
      logger.info("Paste completed successfully")
    } catch {
      paster.restoreClipboard()
      if case ClipboardPasterError.targetAppTerminated = error {
        showPanelAfterTargetTermination()
      } else {
        restorePanelAfterPasteFailure(
          text: text,
          targetApp: targetApp,
          error: error
        )
      }
      logger.error("Paste failed: \(error)")
    }
  }

  /// Restores only the finalized input state after a paste failure. It deliberately
  /// bypasses `showPanel()` so retrying keeps the original paste target and does
  /// not start a new voice-input session.
  private func restorePanelAfterPasteFailure(
    text: String,
    targetApp: NSRunningApplication,
    error: any Error
  ) {
    appState.frontmostApplication = targetApp
    appState.isInputPanelVisible = true
    appState.setInputText(text)
    appState.errorMessage = errorMessage(for: error)
    panel.makeKeyAndOrderFront(nil)
    clearTextView(startEngine: false)
  }

  private func showPanelAfterTargetTermination() {
    appState.isInputPanelVisible = true
    appState.errorMessage = errorMessage(for: ClipboardPasterError.targetAppTerminated)
    panel.makeKeyAndOrderFront(nil)
  }

  func cancel() {
    guard appState.isInputPanelVisible, !isConfirming else {
      logger.debug("cancel() ignored (not visible or confirming)")
      return
    }

    processingConfirmationID = nil
    scriptService.cancelExecution()
    voiceCoordinator.cancelEngine()
    paster.restoreClipboard()
    replacementService.clearPreviews()
    resetStateAndHidePanel()

    logger.info("Panel cancelled and hidden")
  }

  func switchEngine() async {
    guard appState.isInputPanelVisible, !isConfirming else { return }
    await voiceCoordinator.switchEngine()
  }

  func toggleVoiceInput() async {
    guard appState.isInputPanelVisible, !isConfirming else { return }

    if !appState.settings.voiceInput.isVoiceInputEnabled {
      appState.settings.voiceInput.isVoiceInputEnabled = true
      await voiceCoordinator.switchEngine()
    } else {
      appState.settings.voiceInput.isVoiceInputEnabled = false
      await voiceCoordinator.disableEngine()
    }
  }

  // MARK: - Text editing

  func handleTextChanged(_ text: String) {
    if let textView, !textView.hasMarkedText() {
      appState.setInputText(text)
    } else if textView?.hasMarkedText() == true {
      appState.discardScriptUndo()
    }
    appState.errorMessage = nil
    replacementService.handleInput()
    voiceCoordinator.handleTextChanged()
  }

  func cancelPrompt() {
    voiceCoordinator.currentVoiceTarget = .textEditor
    scriptService.cancelPrompt()
  }

  func undoLastScript() {
    scriptService.undoLastScript()
  }

  // MARK: - Private

  private func configureContentView() {
    let hostingView = NSHostingView(
      rootView: InputPanelContent(
        appState: appState,
        onExecuteScript: { [weak self] script in
          await self?.scriptService.execute(script)
        },
        onConfirm: { [weak self] in
          await self?.confirm()
        },
        onSwitchEngine: { [weak self] in
          await self?.toggleVoiceInput()
        },
        onCancelPrompt: { [weak self] in
          self?.cancelPrompt()
        },
        onUndoScript: { [weak self] in
          self?.undoLastScript()
        },
        onPromptFocused: { [weak self] in
          guard let self else { return }
          self.voiceCoordinator.currentVoiceTarget = .prompt
        },
        onAddReplacementRule: { [weak self] rule in
          self?.replacementService.addRule(rule)
        },
        onTextChanged: { [weak self] text in
          self?.handleTextChanged(text)
        },
        onTextCommitted: { [weak self] in
          self?.handleTextCommitted()
        },
        onRefreshReplacementCandidates: { [weak self] in
          self?.replacementService.refreshCandidates()
        },
        onTextViewCreated: { [weak self] view in
          guard let self else { return }
          self.handleTextViewCreated(view)
        },
        onFocusTextEditor: { [weak self] in
          self?.voiceCoordinator.currentVoiceTarget = .textEditor
          self?.focusTextView()
        }
      ))
    let minimumSize = panel.minSize
    panel.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()
    // AppKit ignores minSize when hosting content participates in Auto Layout.
    NSLayoutConstraint.activate([
      hostingView.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumSize.width),
      hostingView.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumSize.height),
    ])
  }

  private func configurePanelCallbacks() {
    panel.onEscape = { [weak self] in
      guard let self else { return }
      if self.appState.promptScript != nil && !self.appState.isRunningScript {
        self.cancelPrompt()
      } else {
        self.cancel()
      }
    }

    panel.onShortcutKey = { [weak self] shortcut in
      guard let self else { return false }
      if let aShortcut = self.appState.settings.script.autoRunShortcutKey,
        shortcut == aShortcut
      {
        self.scriptService.cycleAutoRunScript()
        return true
      }
      if let rShortcut = self.appState.settings.replacement.replacementShortcutKey,
        shortcut == rShortcut,
        !self.appState.settings.replacement.replacementRules.isEmpty
      {
        self.replacementService.replaceSelection()
        return true
      }
      if let script = self.appState.settings.script.scripts.first(where: {
        $0.shortcutKey == shortcut
      }) {
        self.shortcutScriptTask = Task { @MainActor in
          await self.scriptService.execute(script)
        }
        return true
      }
      if self.appState.settings.voiceInput.voiceInputShortcutKey == shortcut,
        self.appState.isInputPanelVisible, !self.isConfirming
      {
        self.voiceShortcutTask = Task { @MainActor in
          await self.toggleVoiceInput()
        }
        return true
      }
      return false
    }
  }

  private func handleTextViewCreated(_ view: VoiceInputTextView) {
    textView = view
    voiceCoordinator.textView = view
    replacementService.textView = view
    scriptService.textView = view
    view.onDisplayTextChanged = { [weak self] in
      self?.replacementService.refreshCandidates()
    }
    view.onCursorMoved = { [weak self] position in
      self?.voiceCoordinator.handleCursorMoved(position)
    }
    view.onVolatileFinalized = { [weak self] volatileText in
      self?.voiceCoordinator.recordLocalFinalization(volatileText)
    }
  }

  private func handleTextCommitted() {
    if let textView {
      appState.setInputText(textView.string)
    }
    replacementService.clearPreviews()
    replacementService.handleInput()
  }

  private func focusTextView() {
    guard let textView else { return }
    textView.makeFirstResponder(in: panel)
  }

  private func clearTextView(startEngine: Bool) {
    if textView?.window != nil {
      resetTextViewContent(startEngine: startEngine)
    } else {
      // Right after makeKeyAndOrderFront the SwiftUI layout may not be done
      // and textView.window is nil; retry one runloop cycle later.
      Task { [weak self] in
        self?.resetTextViewContent(startEngine: startEngine)
      }
    }
  }

  private func resetTextViewContent(startEngine: Bool) {
    guard let textView else { return }
    textView.replaceText(appState.inputText)
    if textView.window != nil {
      textView.makeFirstResponder(in: panel)
      let endOfText = NSRange(location: (textView.string as NSString).length, length: 0)
      textView.setSelectedRange(endOfText)
      textView.scrollRangeToVisible(endOfText)
    }
    if startEngine {
      voiceCoordinator.startEngine()
    }
  }

  private func errorMessage(for error: any Error) -> String {
    switch error {
    case ClipboardPasterError.accessibilityNotTrusted:
      String(
        localized:
          "Enable Koecho in System Settings > Privacy & Security > Accessibility, then retry. If it is already enabled, remove and add the current Koecho again. Restart Koecho only if the permission still does not take effect."
      )
    case ClipboardPasterError.targetAppTerminated:
      String(localized: "Target application has been terminated.")
    case ClipboardPasterError.failedToCreateCGEvent:
      String(localized: "Failed to simulate paste keystroke.")
    default:
      String(describing: error)
    }
  }

}
