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
  public var id: UUID
  public private(set) var kind: ScriptKind
  public private(set) var builtin: BuiltinScript?

  private var customName: String?
  private var customScriptPath: String?
  private var customRequiresPrompt: Bool?

  public var name: String {
    get { builtin?.feature.displayName ?? customName! }
    set {
      guard kind == .custom else { return }
      customName = newValue
    }
  }

  public var displayName: String {
    builtin?.displayName ?? customName!
  }

  public var scriptPath: String {
    get { customScriptPath ?? "" }
    set {
      guard kind == .custom else { return }
      customScriptPath = newValue
    }
  }

  public var shortcutKey: ShortcutKey?
  public var requiresPrompt: Bool {
    get { customRequiresPrompt ?? false }
    set {
      guard kind == .custom else { return }
      customRequiresPrompt = newValue
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
    kind = .custom
    builtin = nil
    customName = name
    customScriptPath = scriptPath
    self.shortcutKey = shortcutKey
    customRequiresPrompt = requiresPrompt
  }

  public init(id: UUID, builtin: BuiltinScript, shortcutKey: ShortcutKey? = nil) {
    self.id = id
    kind = .builtin
    self.builtin = builtin
    customName = nil
    customScriptPath = nil
    self.shortcutKey = shortcutKey
    customRequiresPrompt = nil
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
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    kind = try container.decodeIfPresent(ScriptKind.self, forKey: .kind) ?? .custom
    shortcutKey = try container.decodeIfPresent(ShortcutKey.self, forKey: .shortcutKey)

    switch kind {
    case .custom:
      builtin = nil
      customName = try container.decode(String.self, forKey: .name)
      customScriptPath = try container.decode(String.self, forKey: .scriptPath)
      customRequiresPrompt = try container.decode(Bool.self, forKey: .requiresPrompt)
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
      builtin = builtinScript
      customName = nil
      customScriptPath = nil
      customRequiresPrompt = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(kind, forKey: .kind)
    try container.encodeIfPresent(shortcutKey, forKey: .shortcutKey)

    switch kind {
    case .custom:
      try container.encode(customName!, forKey: .name)
      try container.encode(customScriptPath!, forKey: .scriptPath)
      try container.encode(customRequiresPrompt!, forKey: .requiresPrompt)
    case .builtin:
      let builtin = builtin!
      try container.encode(builtin.feature, forKey: .builtinFeature)
      try container.encodeIfPresent(builtin.indentationWidth, forKey: .indentationWidth)
    }
  }
}
