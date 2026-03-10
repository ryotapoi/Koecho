import Foundation

public enum ModifierKey: String, Codable, CaseIterable, Sendable {
    case command, shift, option, control, fn
}

public enum ModifierSide: String, Codable, CaseIterable, Sendable {
    case left, right
}

public enum TapMode: String, Codable, CaseIterable, Sendable {
    case singleToggle, doubleTapToShow
}

public struct HotkeyConfig: Codable, Equatable, Sendable {
    public var modifierKey: ModifierKey
    public var side: ModifierSide
    public var tapMode: TapMode

    public init(modifierKey: ModifierKey, side: ModifierSide, tapMode: TapMode) {
        self.modifierKey = modifierKey
        self.side = side
        self.tapMode = tapMode
    }

    public static let `default` = HotkeyConfig(modifierKey: .fn, side: .left, tapMode: .singleToggle)
}
