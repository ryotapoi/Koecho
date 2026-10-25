import KoechoCore
import KoechoPlatform
import SwiftUI

struct InputPanelToolbar: View {
  let availableWidth: CGFloat
  let isVoiceInputEnabled: Bool
  var languages = InputPanelLanguages()
  var selectedLanguage = "ja-JP"
  var onSelectLanguage: (String) async -> Void = { _ in }
  @Bindable var scriptSettings: ScriptSettings
  let isRunningScript: Bool
  let hasPromptScript: Bool
  let canUndoScript: Bool
  let hotkeyConfig: HotkeyConfig
  var onSwitchEngine: () async -> Void
  var onUndoScript: () -> Void
  var onConfirm: () async -> Void

  private var hasAutoRunScripts: Bool {
    !scriptSettings.eligibleAutoRunScripts.isEmpty
  }

  private var isVoiceEnabled: Bool {
    isVoiceInputEnabled
  }

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        HStack(spacing: 2) {
          voiceButton
          if languages.hasMultipleLanguages {
            languageMenu
          }
        }
        .disabled(isRunningScript)

        if canUndoScript {
          Button("Undo Script", systemImage: "arrow.uturn.backward") {
            onUndoScript()
          }
          .buttonStyle(.koechoToolbar(isEmphasized: true))
          .disabled(isRunningScript || hasPromptScript)
        }

        Spacer(minLength: 8)

        autoRunMenu

        Button {
          Task { await onConfirm() }
        } label: {
          HStack(spacing: 8) {
            Text(hotkeyConfig.modifierBadge)
              .font(.caption.bold())
            Text("Confirm")
              .font(.caption.bold())
          }
        }
        .accessibilityLabel(Text("Confirm"))
        .buttonStyle(.koechoToolbar(isPrimary: !hasPromptScript))
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(isRunningScript)
      }
      .frame(minWidth: max(0, availableWidth - 24))
      .fixedSize(horizontal: true, vertical: false)
      .padding(.horizontal, 12)
    }
    .scrollBounceBehavior(.basedOnSize)
    .font(.caption)
    .padding(.vertical, 9)
    .background(.regularMaterial)
    .overlay(alignment: .top) {
      Divider()
    }
  }

  private var voiceButton: some View {
    Button {
      Task { await onSwitchEngine() }
    } label: {
      Label {
        ZStack {
          // Reserve the same compact title width for Voice and five-character language codes.
          Text(verbatim: "Voice")
            .hidden()
          Text(verbatim: "en-US")
            .monospaced()
            .hidden()
          Text("Voice")
            .hidden()

          if languages.hasMultipleLanguages {
            Text(InputPanelLanguages.displayCode(for: selectedLanguage))
              .monospaced()
          } else {
            Text("Voice")
          }
        }
        .fixedSize()
      } icon: {
        Image(isVoiceEnabled ? "KoechoStatusItemColor" : "MenuBarIcon")
          .renderingMode(isVoiceEnabled ? .original : .template)
          .resizable()
          .scaledToFit()
          .frame(width: 12, height: 12)
      }
    }
    .accessibilityLabel(Text("Voice"))
    .accessibilityValue(isVoiceEnabled ? Text("On") : Text("Off"))
    .buttonStyle(.koechoToolbar(isEmphasized: isVoiceEnabled))
    .help(!isVoiceEnabled ? String(localized: "Voice input is off") : String(localized: "Voice"))
  }

  private var languageMenu: some View {
    let currentKey = SpeechLocale.normalizationKey(selectedLanguage)
    return Menu {
      ForEach(languages.locales) { locale in
        Button {
          Task { await onSelectLanguage(locale.identifier) }
        } label: {
          if locale.normalizedKey == currentKey {
            Label(locale.displayName, systemImage: "checkmark")
          } else {
            Text(locale.displayName)
          }
        }
      }
    } label: {
      Image(systemName: "chevron.down")
    }
    .menuIndicator(.hidden)
    .menuStyle(.borderlessButton)
    .fixedSize()
    .buttonStyle(.koechoToolbar(isEmphasized: isVoiceEnabled))
    .accessibilityLabel(Text("Recognition Language"))
    .help(String(localized: "Recognition Language"))
  }

  private func helpText(_ label: String, shortcut: ShortcutKey?) -> String {
    if let shortcut {
      "\(label) (\(shortcut.displayName))"
    } else {
      label
    }
  }

  @ViewBuilder
  private var autoRunMenu: some View {
    if hasAutoRunScripts {
      Menu {
        Text("Auto-run on Confirm")
        AutoRunScriptMenuContent(scriptSettings: scriptSettings)
      } label: {
        AutoRunScriptLabel(script: scriptSettings.autoRunScript)
      }
      .labelStyle(.titleAndIcon)
      .menuStyle(.borderlessButton)
      .buttonStyle(.koechoToolbar())
      .fixedSize()
      .help(
        helpText(
          String(localized: "Cycle auto-run script selection"),
          shortcut: scriptSettings.autoRunShortcutKey)
      )
    } else {
      Button {
      } label: {
        AutoRunScriptLabel(script: nil)
      }
      .buttonStyle(.koechoToolbar())
      .disabled(true)
    }
  }
}

extension HotkeyConfig {
  var modifierBadge: String {
    switch modifierKey {
    case .command: "\u{2318}"
    case .shift: "\u{21E7}"
    case .option: "\u{2325}"
    case .control: "\u{2303}"
    case .fn: "fn"
    }
  }
}

// MARK: - Previews

#Preview("Voice button widths") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-voice-widths")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  let languages = InputPanelLanguages()
  languages.locales = [
    LocaleItem(
      identifier: "ja-JP", displayName: "Japanese",
      normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
    LocaleItem(
      identifier: "en-US", displayName: "English (US)",
      normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: true),
  ]
  return VStack(spacing: 0) {
    ForEach(["Voice", "音声", "ja-JP", "en-US"], id: \.self) { title in
      InputPanelToolbar(
        availableWidth: 350,
        isVoiceInputEnabled: true,
        languages: title == "Voice" || title == "音声" ? InputPanelLanguages() : languages,
        selectedLanguage: title,
        scriptSettings: scriptSettings,
        isRunningScript: false,
        hasPromptScript: false,
        canUndoScript: false,
        hotkeyConfig: .default,
        onSwitchEngine: {},
        onUndoScript: {},
        onConfirm: {}
      )
      .environment(\.locale, Locale(identifier: title == "音声" ? "ja" : "en"))
    }
  }
  .frame(width: 350)
}

#Preview("Full") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-full")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  var both = Script(name: "Format", scriptPath: "format.sh")
  both.display = .init(name: "Format", symbolName: "text.alignleft")
  var symbolOnly = Script(name: "Symbol only", scriptPath: "symbol.sh")
  symbolOnly.display = .init(name: "", symbolName: "star")
  var titleOnly = Script(name: "Title only", scriptPath: "title.sh")
  titleOnly.display = .init(name: "Title only", symbolName: "")
  scriptSettings.scripts = [both, symbolOnly, titleOnly]
  scriptSettings.autoRunScriptId = both.id
  let languages = InputPanelLanguages()
  languages.locales = [
    LocaleItem(
      identifier: "ja-JP", displayName: "Japanese",
      normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
    LocaleItem(
      identifier: "en-US", displayName: "English (US)",
      normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: true),
  ]
  return InputPanelToolbar(
    availableWidth: 560,
    isVoiceInputEnabled: true,
    languages: languages,
    selectedLanguage: "ja-JP",
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    canUndoScript: true,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onUndoScript: {},
    onConfirm: {}
  )
  .frame(width: 560, height: 40)
}

#Preview("Running Script") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-running")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  return InputPanelToolbar(
    availableWidth: 350,
    isVoiceInputEnabled: false,
    scriptSettings: scriptSettings,
    isRunningScript: true,
    hasPromptScript: false,
    canUndoScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onUndoScript: {},
    onConfirm: {}
  )
  .frame(width: 350, height: 40)
}

#Preview("Dark") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-dark")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  scriptSettings.scripts = [
    Script(name: "Format", scriptPath: "format.sh"),
    Script(name: "AI", scriptPath: "ai.sh"),
  ]
  let languages = InputPanelLanguages()
  languages.locales = [
    LocaleItem(
      identifier: "ja-JP", displayName: "Japanese",
      normalizedKey: SpeechLocale.normalizationKey("ja-JP"), isReserved: true),
    LocaleItem(
      identifier: "en-US", displayName: "English (US)",
      normalizedKey: SpeechLocale.normalizationKey("en-US"), isReserved: true),
  ]
  return InputPanelToolbar(
    availableWidth: 350,
    isVoiceInputEnabled: false,
    languages: languages,
    selectedLanguage: "en-US",
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    canUndoScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onUndoScript: {},
    onConfirm: {}
  )
  .frame(width: 350, height: 40)
  .preferredColorScheme(.dark)
}

#Preview("Prompting") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-prompting")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  scriptSettings.scripts = [
    Script(name: "Format", scriptPath: "format.sh"),
    Script(name: "AI", scriptPath: "ai.sh"),
  ]
  return InputPanelToolbar(
    availableWidth: 350,
    isVoiceInputEnabled: true,
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: true,
    canUndoScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onUndoScript: {},
    onConfirm: {}
  )
  .frame(width: 350, height: 40)
  .opacity(0.45)
}

#Preview("No Rules") {
  let defaults = UserDefaults(suiteName: "preview-toolbar-no-rules")!
  let scriptSettings = ScriptSettings(defaults: defaults)
  return InputPanelToolbar(
    availableWidth: 350,
    isVoiceInputEnabled: true,
    scriptSettings: scriptSettings,
    isRunningScript: false,
    hasPromptScript: false,
    canUndoScript: false,
    hotkeyConfig: .default,
    onSwitchEngine: {},
    onUndoScript: {},
    onConfirm: {}
  )
  .frame(width: 350, height: 40)
}
