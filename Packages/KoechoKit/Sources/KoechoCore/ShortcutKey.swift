import Foundation

public enum Modifier: String, Codable, Comparable, Sendable {
    case control, option, shift, command

    /// macOS standard display order: ⌃ ⌥ ⇧ ⌘
    public var sortOrder: Int {
        switch self {
        case .control: 0
        case .option:  1
        case .shift:   2
        case .command: 3
        }
    }

    public static func < (lhs: Modifier, rhs: Modifier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var symbol: String {
        switch self {
        case .control: "\u{2303}"  // ⌃
        case .option:  "\u{2325}"  // ⌥
        case .shift:   "\u{21E7}"  // ⇧
        case .command: "\u{2318}"  // ⌘
        }
    }
}

public struct ShortcutKey: Codable, Equatable, Hashable, Sendable {
    public var modifiers: Set<Modifier>
    public var character: String

    public init(modifiers: Set<Modifier>, character: String) {
        self.modifiers = modifiers
        self.character = character.lowercased()
    }

    public var displayName: String {
        let syms = modifiers.sorted().map(\.symbol).joined()
        return "\(syms)\(character.uppercased())"
    }

    /// Validate that the character is a printable ASCII character (0x21-0x7E).
    public static func isPrintableASCII(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else { return false }
        return scalar.value >= 0x21 && scalar.value <= 0x7E
    }

    /// Validate that modifiers include at least one of Ctrl/Cmd/Option (Shift alone is not enough).
    public static func hasRequiredModifier(_ modifiers: Set<Modifier>) -> Bool {
        !modifiers.intersection([.control, .command, .option]).isEmpty
    }
}
