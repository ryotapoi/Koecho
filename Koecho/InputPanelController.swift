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
  private var textView: VoiceInputTextView?
  private(set) var panel: InputPanel
  private var replacementService: ReplacementService!
  private var scriptService: ScriptExecutionService!
  private(set) var shortcutScriptTask: Task<Void, Never>?
  // Internal getter so tests can reach replay state directly instead of
  // production-unused forwarding properties on the controller.
  private(set) var voiceCoordinator: VoiceInputCoordinator!
  private var lifecycleManager: PanelLifecycleManager!
  private var lastEnabledVoiceInputMode: VoiceInputMode = defaultEnabledVoiceInputMode()

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

    self.panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 240))

    self.lifecycleManager = PanelLifecycleManager(
      appState: appState,
      selectedTextReader: selectedTextReader,
      ducker: ducker,
      panel: panel
    )

    let engineFactory =
      makeEngine ?? { () -> any VoiceInputEngine in
        if #available(macOS 26, *),
          appState.settings.voiceInput.effectiveVoiceInputMode == .speechAnalyzer
        {
          let locale = Locale(identifier: appState.settings.voiceInput.speechAnalyzerLocale)
          return SpeechAnalyzerEngine(
            locale: locale,
            deviceUID: appState.settings.voiceInput.audioInputDeviceUID
          )
        }
        return DictationEngine()
      }

    self.voiceCoordinator = VoiceInputCoordinator(
      appState: appState,
      makeEngine: engineFactory,
      panel: panel
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

    voiceCoordinator.onAutoReplacement = { [weak self] in
      self?.replacementService.applyOrPreview()
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
      paster: ClipboardPaster(pasteDelay: appState.settings.paste.pasteDelay),
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

    let voiceEnabled = appState.settings.voiceInput.effectiveVoiceInputMode != .off
    lifecycleManager.show(duckVolume: voiceEnabled)
    if voiceEnabled {
      voiceCoordinator.prepareForShow()
    } else {
      voiceCoordinator.prepareForShowWithoutEngine()
    }
    clearTextView(startEngine: voiceEnabled)

    logger.info("Panel shown, isKeyWindow: \(self.panel.isKeyWindow)")
  }

  func confirm() async {
    guard appState.isInputPanelVisible, !isConfirming, !appState.isRunningScript else { return }

    let rawText = await finalizeDictation()
    let text = replacementService.applyRules(to: rawText)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      dismissAsEmptyConfirm()
      return
    }

    guard let preparedText = await applyAutoRunScript(to: text) else { return }
    await pasteAndRecord(preparedText)
  }

  /// Confirm phase 1: stop dictation and collect the finalized text,
  /// clearing the text view.
  private func finalizeDictation() async -> String {
    replacementService.clearPreviews()
    await voiceCoordinator.stopEngine()
    voiceCoordinator.finalizeRemainingVolatile()

    let rawText: String
    if let textView {
      let tvString = textView.finalizedString
      rawText = tvString.isEmpty ? appState.inputText : tvString
    } else {
      rawText = appState.inputText
    }
    textView?.setString("", suppressingCallbacks: true)
    return rawText
  }

  /// Confirm phase 2 (empty result): treat the confirm as a cancel.
  private func dismissAsEmptyConfirm() {
    paster.restoreClipboard()
    resetStateAndHidePanel()
    logger.info("confirm() with empty text, treated as cancel")
  }

  /// Shared teardown: resets dictation state, clears panel app state,
  /// and hides the panel.
  private func resetStateAndHidePanel() {
    voiceCoordinator.resetState()
    lifecycleManager.clearState()
    lifecycleManager.hide()
  }

  /// Confirm phase 3: run the configured auto-run script on `text`.
  /// Returns the text to paste, or nil when the confirm was cancelled
  /// mid-flight or the script failed (the error is surfaced here).
  private func applyAutoRunScript(to text: String) async -> String? {
    guard let autoScript = appState.settings.script.autoRunScript else { return text }
    guard appState.isInputPanelVisible else { return nil }

    appState.inputText = text
    textView?.setString(text, suppressingCallbacks: true)

    appState.isRunningScript = true
    defer { appState.isRunningScript = false }

    do {
      let transformed = try await scriptService.runAutoScript(autoScript, on: text)
      guard appState.isInputPanelVisible else { return nil }
      return transformed
    } catch {
      guard appState.isInputPanelVisible else { return nil }
      appState.inputText = text
      textView?.setString(text, suppressingCallbacks: true)
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
      try await paster.paste(text: text, to: targetApp, using: .general)
      historyStore.add(text: text, settings: appState.settings.history)
      logger.info("Paste completed successfully")
    } catch {
      paster.restoreClipboard()
      appState.isInputPanelVisible = true
      panel.makeKeyAndOrderFront(nil)
      appState.inputText = text
      appState.errorMessage = errorMessage(for: error)
      logger.error("Paste failed: \(error)")
    }
  }

  func cancel() {
    guard appState.isInputPanelVisible, !isConfirming else {
      logger.debug("cancel() ignored (not visible or confirming)")
      return
    }

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

    if appState.settings.voiceInput.effectiveVoiceInputMode == .off {
      appState.settings.voiceInput.voiceInputMode = lastEnabledVoiceInputMode
      await voiceCoordinator.switchEngine()
    } else {
      lastEnabledVoiceInputMode = appState.settings.voiceInput.effectiveVoiceInputMode
      await voiceCoordinator.disableEngine()
      appState.settings.voiceInput.voiceInputMode = .off
    }
  }

  // MARK: - Text editing

  func handleTextChanged(_ text: String) {
    if let textView, !textView.hasMarkedText() {
      appState.inputText = text
    }
    appState.errorMessage = nil
    if appState.settings.replacement.isAutoReplacementEnabled {
      replacementService.applyOrPreview()
    }
    voiceCoordinator.handleTextChanged()
  }

  func applyReplacementRulesNow() {
    replacementService.applyNow()
  }

  func addReplacementRule(_ rule: ReplacementRule) {
    replacementService.addRule(rule)
  }

  func executeScript(_ script: Script) async {
    await scriptService.execute(script)
  }

  func cancelPrompt() {
    voiceCoordinator.currentVoiceTarget = .textEditor
    scriptService.cancelPrompt()
  }

  func cycleAutoRunScript() {
    scriptService.cycleAutoRunScript()
  }

  // MARK: - VoiceInputDelegate forwarding

  func voiceInput(didFinalize text: String) {
    voiceCoordinator.voiceInput(didFinalize: text)
  }

  func voiceInput(didUpdateVolatile text: String) {
    voiceCoordinator.voiceInput(didUpdateVolatile: text)
  }

  func voiceInput(didEncounterError error: VoiceInputEngineError) {
    voiceCoordinator.voiceInput(didEncounterError: error)
  }

  func voiceInput(didUpdateStatus status: VoiceInputEngineStatus?) {
    voiceCoordinator.voiceInput(didUpdateStatus: status)
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
        onApplyReplacementRules: { [weak self] in
          self?.replacementService.applyOrPreview()
        },
        onPromptFocused: { [weak self] in
          guard let self else { return }
          self.voiceCoordinator.currentVoiceTarget = .prompt
          self.voiceCoordinator.restartDictationIfNeeded()
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
        onTextViewCreated: { [weak self] view in
          guard let self else { return }
          self.handleTextViewCreated(view)
        },
        onFocusTextEditor: { [weak self] in
          self?.voiceCoordinator.currentVoiceTarget = .textEditor
          self?.focusTextView()
        }
      ))
    panel.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()
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
        self.replacementService.applyOrPreview()
        return true
      }
      guard
        let script = self.appState.settings.script.scripts.first(where: {
          $0.shortcutKey == shortcut
        })
      else { return false }
      self.shortcutScriptTask = Task { @MainActor in
        await self.scriptService.execute(script)
      }
      return true
    }
  }

  private func handleTextViewCreated(_ view: VoiceInputTextView) {
    textView = view
    voiceCoordinator.textView = view
    replacementService.textView = view
    scriptService.textView = view
    view.onCursorMoved = { [weak self] position in
      self?.voiceCoordinator.handleCursorMoved(position)
    }
    view.onVolatileFinalized = { [weak self] volatileText in
      self?.voiceCoordinator.recordLocalFinalization(volatileText)
    }
    voiceCoordinator.configureEngineWithTextView()
  }

  private func handleTextCommitted() {
    if let textView {
      appState.inputText = textView.string
    }
    replacementService.clearPreviews()
    if appState.settings.replacement.isAutoReplacementEnabled {
      replacementService.applyOrPreview()
    }
  }

  private func focusTextView() {
    guard let textView else { return }
    textView.makeFirstResponder(in: panel)
  }

  private static func defaultEnabledVoiceInputMode() -> VoiceInputMode {
    if #available(macOS 26, *) { return .speechAnalyzer }
    return .dictation
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
    textView.setString(appState.inputText, suppressingCallbacks: true)
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
          "Accessibility permission required. Open System Settings > Privacy & Security > Accessibility."
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
