import AppKit
import KoechoCore

enum ScriptPresentation {
  static func label(for script: Script) -> String {
    script.displayName
  }

  static func symbolName(for script: Script) -> String {
    if let display = script.display { return display.symbolName }
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

  static func identification(for script: Script) -> String {
    let label = label(for: script)
    if !label.isEmpty { return label }
    let symbol = symbolName(for: script)
    if !symbol.isEmpty { return symbol }
    return script.builtin?.displayName ?? script.name
  }

  static func validatedDisplay(name: String, symbolName: String) -> Script.Display? {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let symbolName = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty || !symbolName.isEmpty else { return nil }
    guard symbolName.isEmpty || isAvailableSymbol(symbolName) else {
      return nil
    }
    return Script.Display(name: name, symbolName: symbolName)
  }

  static func isAvailableSymbol(_ name: String) -> Bool {
    NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
  }
}
