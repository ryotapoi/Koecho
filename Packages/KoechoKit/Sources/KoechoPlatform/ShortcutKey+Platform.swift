import AppKit
import KoechoCore

extension Modifier {
    public var flag: NSEvent.ModifierFlags {
        switch self {
        case .control: .control
        case .option:  .option
        case .shift:   .shift
        case .command: .command
        }
    }
}

extension ShortcutKey {
    /// Build a Set<Modifier> from NSEvent.ModifierFlags.
    public static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<Modifier> {
        let device = flags.intersection(.deviceIndependentFlagsMask)
        var result = Set<Modifier>()
        if device.contains(.control) { result.insert(.control) }
        if device.contains(.option)  { result.insert(.option) }
        if device.contains(.shift)   { result.insert(.shift) }
        if device.contains(.command) { result.insert(.command) }
        return result
    }
}
