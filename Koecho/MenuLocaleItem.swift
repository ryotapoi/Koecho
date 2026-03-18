import Foundation

struct MenuLocaleItem: Identifiable, Equatable {
    let identifier: String
    let displayName: String
    let normalizedKey: String
    var id: String { identifier }
}
