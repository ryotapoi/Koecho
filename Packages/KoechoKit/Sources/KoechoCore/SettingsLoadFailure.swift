public enum SettingsLoadFailure: String, CaseIterable, Hashable, Sendable {
  case scripts
  case autoRunScriptId
  case autoRunShortcut
  case scriptTimeout
  case replacementRules
  case replacementShortcut
  case isAutoReplacementEnabled
  case voiceInputShortcut
}
