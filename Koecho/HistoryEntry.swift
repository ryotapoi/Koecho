import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var text: String
    var timestamp: Date

    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}
