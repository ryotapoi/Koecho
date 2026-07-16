import KoechoCore
import KoechoPlatform
import SwiftUI

struct InputPanelContent: View {
  private let cornerRadius: CGFloat = 20

  @Bindable var appState: AppState
  var onExecuteScript: (Script) async -> Void
  var onConfirm: () async -> Void
  var onSwitchEngine: () async -> Void
  var onCancelPrompt: () -> Void
  var onApplyReplacementRules: () -> Void = {}
  var onPromptFocused: () -> Void = {}
  var onAddReplacementRule: (ReplacementRule) -> Void = { _ in }
  var onTextChanged: (String) -> Void = { _ in }
  var onTextCommitted: () -> Void = {}
  var onTextViewCreated: (VoiceInputTextView) -> Void = { _ in }
  var onFocusTextEditor: () -> Void = {}

  @FocusState private var isPromptFocused: Bool

  private var hasPromptScript: Bool {
    appState.promptScript != nil
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 8) {
        inputEditor
        promptInput
        statusMessage
        scriptStrip
      }
      .padding(.leading, 4)
      .padding(.trailing, 4)
      .padding(.top, 0)
      .padding(.bottom, 8)

      InputPanelToolbar(
        voiceInputMode: appState.settings.voiceInput.effectiveVoiceInputMode,
        replacementRules: appState.settings.replacement.replacementRules,
        scriptSettings: appState.settings.script,
        isRunningScript: appState.isRunningScript,
        hasPromptScript: hasPromptScript,
        hotkeyConfig: appState.settings.hotkey.hotkeyConfig,
        onSwitchEngine: onSwitchEngine,
        onApplyReplacementRules: onApplyReplacementRules,
        onConfirm: onConfirm,
        replacementShortcutKey: appState.settings.replacement.replacementShortcutKey
      )
      .opacity(hasPromptScript ? 0.45 : 1.0)
    }
    .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
    .background {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.ultraThinMaterial)
        .ignoresSafeArea(.container, edges: .top)
    }
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        .ignoresSafeArea(.container, edges: .top)
    }
    .shadow(color: .black.opacity(0.18), radius: 24, y: 14)
    .onChange(of: appState.promptScript) {
      if appState.promptScript != nil {
        isPromptFocused = true
        onPromptFocused()
      } else {
        isPromptFocused = false
        onFocusTextEditor()
      }
    }
  }

  private var inputEditor: some View {
    ZStack(alignment: .topLeading) {
      VoiceInputTextEditor(
        text: appState.inputText,
        isDisabled: appState.isRunningScript,
        onTextChanged: onTextChanged,
        onTextCommitted: onTextCommitted,
        onAddReplacementRule: { pattern in
          appState.pendingReplacementPattern = pattern
        },
        onViewCreated: onTextViewCreated
      )
      .opacity(inputEditorOpacity)
      .frame(minHeight: 120, maxHeight: CGFloat.infinity)
      .popover(
        isPresented: Binding(
          get: { appState.pendingReplacementPattern != nil },
          set: { if !$0 { appState.pendingReplacementPattern = nil } }
        )
      ) {
        if let pattern = appState.pendingReplacementPattern {
          AddReplacementRuleView(
            pattern: pattern,
            onAdd: { rule in
              onAddReplacementRule(rule)
            },
            onCancel: {
              appState.pendingReplacementPattern = nil
            }
          )
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private var promptInput: some View {
    if appState.promptScript != nil {
      PromptInputView(
        promptText: $appState.promptText,
        volatilePromptText: $appState.volatilePromptText,
        promptScript: appState.promptScript,
        isRunningScript: appState.isRunningScript,
        onExecuteScript: onExecuteScript,
        onCancelPrompt: onCancelPrompt,
        isFocused: $isPromptFocused
      )
    }
  }

  @ViewBuilder
  private var statusMessage: some View {
    if let status = appState.voiceEngineStatus {
      HStack(spacing: 4) {
        ProgressView()
          .controlSize(.small)
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    if let errorMessage = appState.errorMessage {
      Text(errorMessage)
        .font(.caption)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var scriptStrip: some View {
    InputPanelScriptStrip(
      scripts: appState.settings.script.scripts,
      selectedScript: appState.promptScript,
      isRunningScript: appState.isRunningScript,
      hasPromptScript: hasPromptScript,
      onExecuteScript: onExecuteScript,
      onReorderScripts: { reordered in
        appState.settings.script.scripts = reordered
      }
    )
    .opacity(hasPromptScript ? 0.45 : 1.0)
  }

  private var inputEditorOpacity: Double {
    if hasPromptScript {
      return 0.38
    }
    return appState.voiceEngineStatus != nil ? 0.5 : 1.0
  }
}

// MARK: - Previews

#Preview("With Text") {
  let defaults = UserDefaults(suiteName: "preview-panel-withText")!
  let settings = KoechoCore.Settings(defaults: defaults)
  settings.voiceInput.voiceInputMode = .dictation
  let appState = AppState(settings: settings)
  appState.setInputText("Hello, this is a voice transcription.")
  return InputPanelContent(
    appState: appState,
    onExecuteScript: { _ in },
    onConfirm: {},
    onSwitchEngine: {},
    onCancelPrompt: {}
  )
  .frame(width: 300, height: 200)
}

#Preview("Empty") {
  let defaults = UserDefaults(suiteName: "preview-panel-empty")!
  let settings = KoechoCore.Settings(defaults: defaults)
  settings.voiceInput.voiceInputMode = .dictation
  let appState = AppState(settings: settings)
  return InputPanelContent(
    appState: appState,
    onExecuteScript: { _ in },
    onConfirm: {},
    onSwitchEngine: {},
    onCancelPrompt: {}
  )
  .frame(width: 300, height: 200)
}
