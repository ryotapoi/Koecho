import Foundation

public enum ScriptKind: String, Codable, Equatable, Hashable, Sendable {
  case custom
  case builtin
}

public enum BuiltinScriptFeature: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
  case decreaseIndent
  case increaseIndent
  case blockQuote

  public var displayName: String {
    switch self {
    case .decreaseIndent:
      "Decrease Indent"
    case .increaseIndent:
      "Increase Indent"
    case .blockQuote:
      "Block Quote"
    }
  }

  public var supportsIndentationWidth: Bool {
    self == .decreaseIndent || self == .increaseIndent
  }
}

public enum BuiltinScriptIndentationWidth: Int, Codable, Equatable, Hashable, Sendable {
  case two = 2
  case four = 4
}

public struct BuiltinScript: Codable, Equatable, Sendable {
  public let feature: BuiltinScriptFeature
  public let indentationWidth: BuiltinScriptIndentationWidth?

  public init?(feature: BuiltinScriptFeature, indentationWidth: BuiltinScriptIndentationWidth? = nil) {
    guard feature.supportsIndentationWidth == (indentationWidth != nil) else { return nil }
    self.feature = feature
    self.indentationWidth = indentationWidth
  }

  public var displayName: String {
    guard let indentationWidth else { return feature.displayName }
    return "\(feature.displayName) (\(indentationWidth.rawValue) spaces)"
  }
}

public struct Script: Codable, Identifiable, Equatable, Sendable {
  public struct Display: Codable, Equatable, Sendable {
    public var name: String
    public var symbolName: String

    public init(name: String, symbolName: String) {
      self.name = name
      self.symbolName = symbolName
    }
  }

  private enum Content: Equatable, Sendable {
    case custom(name: String, scriptPath: String, requiresPrompt: Bool)
    case builtin(BuiltinScript)
  }

  public var id: UUID
  private var content: Content
  public var display: Display?

  public var kind: ScriptKind {
    switch content {
    case .custom:
      .custom
    case .builtin:
      .builtin
    }
  }

  public var builtin: BuiltinScript? {
    guard case let .builtin(builtin) = content else { return nil }
    return builtin
  }

  public var name: String {
    get {
      switch content {
      case let .custom(name, _, _):
        name
      case let .builtin(builtin):
        builtin.feature.displayName
      }
    }
    set {
      guard case let .custom(_, scriptPath, requiresPrompt) = content else { return }
      content = .custom(name: newValue, scriptPath: scriptPath, requiresPrompt: requiresPrompt)
    }
  }

  public var displayName: String {
    if let display { return display.name }
    return switch content {
    case let .custom(name, _, _):
      name
    case .builtin:
      ""
    }
  }

  public var scriptPath: String {
    get {
      guard case let .custom(_, scriptPath, _) = content else { return "" }
      return scriptPath
    }
    set {
      guard case let .custom(name, _, requiresPrompt) = content else { return }
      content = .custom(name: name, scriptPath: newValue, requiresPrompt: requiresPrompt)
    }
  }

  public var shortcutKey: ShortcutKey?
  public var requiresPrompt: Bool {
    get {
      guard case let .custom(_, _, requiresPrompt) = content else { return false }
      return requiresPrompt
    }
    set {
      guard case let .custom(name, scriptPath, _) = content else { return }
      content = .custom(name: name, scriptPath: scriptPath, requiresPrompt: newValue)
    }
  }

  public init(
    id: UUID = UUID(),
    name: String,
    scriptPath: String,
    shortcutKey: ShortcutKey? = nil,
    requiresPrompt: Bool = false
  ) {
    self.id = id
    content = .custom(name: name, scriptPath: scriptPath, requiresPrompt: requiresPrompt)
    display = nil
    self.shortcutKey = shortcutKey
  }

  public init(id: UUID, builtin: BuiltinScript, shortcutKey: ShortcutKey? = nil, display: Display? = nil) {
    self.id = id
    content = .builtin(builtin)
    self.display = display
    self.shortcutKey = shortcutKey
  }

  public static let defaultBuiltins: [Script] = [
    Script(
      id: UUID(uuidString: "9CD87871-4E3C-4731-9DCE-BD8B3F2BCBC9")!,
      builtin: BuiltinScript(feature: .decreaseIndent, indentationWidth: .two)!
    ),
    Script(
      id: UUID(uuidString: "D1A934FB-7C54-4ABF-A05C-8A9A8DD69A9D")!,
      builtin: BuiltinScript(feature: .increaseIndent, indentationWidth: .two)!
    ),
    Script(
      id: UUID(uuidString: "A8353637-82A5-49F2-93C8-F268A0A790D5")!,
      builtin: BuiltinScript(feature: .blockQuote)!
    ),
  ]

  private enum CodingKeys: String, CodingKey {
    case id
    case kind
    case name
    case scriptPath
    case shortcutKey
    case requiresPrompt
    case builtinFeature
    case indentationWidth
    case display
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    let kind = try container.decodeIfPresent(ScriptKind.self, forKey: .kind) ?? .custom
    shortcutKey = try container.decodeIfPresent(ShortcutKey.self, forKey: .shortcutKey)
    display = try container.decodeIfPresent(Display.self, forKey: .display)

    switch kind {
    case .custom:
      content = .custom(
        name: try container.decode(String.self, forKey: .name),
        scriptPath: try container.decode(String.self, forKey: .scriptPath),
        requiresPrompt: try container.decode(Bool.self, forKey: .requiresPrompt)
      )
    case .builtin:
      let feature = try container.decode(BuiltinScriptFeature.self, forKey: .builtinFeature)
      let indentationWidth = try container.decodeIfPresent(
        BuiltinScriptIndentationWidth.self,
        forKey: .indentationWidth
      )
      guard let builtinScript = BuiltinScript(feature: feature, indentationWidth: indentationWidth) else {
        throw DecodingError.dataCorruptedError(
          forKey: .indentationWidth,
          in: container,
          debugDescription: "Builtin feature and indentation width are incompatible"
        )
      }
      content = .builtin(builtinScript)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(kind, forKey: .kind)
    try container.encodeIfPresent(shortcutKey, forKey: .shortcutKey)
    try container.encodeIfPresent(display, forKey: .display)

    switch content {
    case let .custom(name, scriptPath, requiresPrompt):
      try container.encode(name, forKey: .name)
      try container.encode(scriptPath, forKey: .scriptPath)
      try container.encode(requiresPrompt, forKey: .requiresPrompt)
    case let .builtin(builtin):
      try container.encode(builtin.feature, forKey: .builtinFeature)
      try container.encodeIfPresent(builtin.indentationWidth, forKey: .indentationWidth)
    }
  }
}
