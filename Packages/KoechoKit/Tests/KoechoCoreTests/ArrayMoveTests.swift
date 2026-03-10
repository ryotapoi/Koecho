import Foundation
import Testing
@testable import KoechoCore

struct ArrayMoveTests {
    @Test func moveForward() {
        var arr = [0, 1, 2, 3, 4]
        arr.moveElements(fromOffsets: IndexSet(integer: 1), toOffset: 4)
        #expect(arr == [0, 2, 3, 1, 4])
    }

    @Test func moveBackward() {
        var arr = [0, 1, 2, 3, 4]
        arr.moveElements(fromOffsets: IndexSet(integer: 3), toOffset: 1)
        #expect(arr == [0, 3, 1, 2, 4])
    }

    @Test func moveMultiple() {
        var arr = [0, 1, 2, 3, 4]
        arr.moveElements(fromOffsets: IndexSet([0, 2]), toOffset: 4)
        #expect(arr == [1, 3, 0, 2, 4])
    }

    @Test func moveToSamePosition() {
        var arr = [0, 1, 2]
        arr.moveElements(fromOffsets: IndexSet(integer: 1), toOffset: 1)
        #expect(arr == [0, 1, 2])
    }

    @Test func moveToEnd() {
        var arr = [0, 1, 2]
        arr.moveElements(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(arr == [1, 2, 0])
    }

    @Test func moveToBeginning() {
        var arr = [0, 1, 2]
        arr.moveElements(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(arr == [2, 0, 1])
    }
}
