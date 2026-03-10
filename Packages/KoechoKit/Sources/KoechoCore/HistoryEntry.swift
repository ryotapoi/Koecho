import Foundation

public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var timestamp: Date

    public init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}
