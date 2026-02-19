import Foundation

struct Script: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var scriptPath: String
    var shortcutKey: ShortcutKey?
    var requiresPrompt: Bool

    init(
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
