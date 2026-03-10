import Foundation

public struct Script: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var scriptPath: String
    public var shortcutKey: ShortcutKey?
    public var requiresPrompt: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        scriptPath: String,
        shortcutKey: ShortcutKey? = nil,
        requiresPrompt: Bool = false
    ) {
        self.id = id
        self.name = name
        self.scriptPath = scriptPath
        self.shortcutKey = shortcutKey
        self.requiresPrompt = requiresPrompt
    }
}
