import AppKit

enum Modifier: String, Codable, Comparable, Sendable {
    case control, option, shift, command

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .control: .control
        case .option:  .option
        case .shift:   .shift
        case .command: .command
        }
    }

    /// macOS standard display order: ⌃ ⌥ ⇧ ⌘
    var sortOrder: Int {
        switch self {
        case .control: 0
        case .option:  1
        case .shift:   2
        case .command: 3
        }
    }

    static func < (lhs: Modifier, rhs: Modifier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    var symbol: String {
        switch self {
        case .control: "\u{2303}"  // ⌃
        case .option:  "\u{2325}"  // ⌥
        case .shift:   "\u{21E7}"  // ⇧
        case .command: "\u{2318}"  // ⌘
        }
    }
}

struct ShortcutKey: Codable, Equatable, Hashable, Sendable {
    var modifiers: Set<Modifier>
    var character: String

    init(modifiers: Set<Modifier>, character: String) {
        self.modifiers = modifiers
        self.character = character.lowercased()
    }

    var displayName: String {
        let syms = modifiers.sorted().map(\.symbol).joined()
        return "\(syms)\(character.uppercased())"
    }

    /// Build a Set<Modifier> from NSEvent.ModifierFlags.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<Modifier> {
        let device = flags.intersection(.deviceIndependentFlagsMask)
        var result = Set<Modifier>()
        if device.contains(.control) { result.insert(.control) }
        if device.contains(.option)  { result.insert(.option) }
        if device.contains(.shift)   { result.insert(.shift) }
        if device.contains(.command) { result.insert(.command) }
        return result
    }

    /// Validate that the character is a printable ASCII character (0x21-0x7E).
    static func isPrintableASCII(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else { return false }
        return scalar.value >= 0x21 && scalar.value <= 0x7E
    }

    /// Validate that modifiers include at least one of Ctrl/Cmd/Option (Shift alone is not enough).
    static func hasRequiredModifier(_ modifiers: Set<Modifier>) -> Bool {
        !modifiers.intersection([.control, .command, .option]).isEmpty
    }
}
