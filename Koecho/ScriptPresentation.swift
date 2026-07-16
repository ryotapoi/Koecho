import KoechoCore

enum ScriptPresentation {
  static func label(for script: Script) -> String {
    script.displayName
  }

  static func symbolName(for script: Script) -> String {
    guard let feature = script.builtin?.feature else {
      return script.requiresPrompt ? "text.bubble.fill" : "play.fill"
    }

    switch feature {
    case .decreaseIndent:
      return "decrease.indent"
    case .increaseIndent:
      return "increase.indent"
    case .blockQuote:
      return "text.quote"
    }
  }
}
