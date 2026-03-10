import Foundation

extension Array {
    public mutating func moveElements(fromOffsets source: IndexSet, toOffset destination: Int) {
        let items = source.map { self[$0] }
        for index in source.sorted().reversed() {
            remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        insert(contentsOf: items, at: adjustedDestination)
    }
}
