#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorSelectionSetTests: XCTestCase {

    // MARK: - Creation

    func testInitialSelection() {
        let set = EditorSelectionSet.initial
        XCTAssertEqual(set.count, 1)
        XCTAssertEqual(set.primary?.range.location, 0)
        XCTAssertEqual(set.primary?.range.length, 0)
        XCTAssertFalse(set.isMultiCursor)
    }

    func testEmptySelectionsFallbackToInitial() {
        let set = EditorSelectionSet(selections: [])
        XCTAssertEqual(set.count, 1)
        XCTAssertEqual(set.primary?.range.location, 0)
    }

    func testSingleSelection() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 10, length: 5))
        ])
        XCTAssertEqual(set.count, 1)
        XCTAssertEqual(set.primary?.range.location, 10)
        XCTAssertEqual(set.primary?.range.length, 5)
        XCTAssertFalse(set.isMultiCursor)
    }

    func testMultipleSelections() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 20, length: 3)),
            EditorSelection(range: EditorRange(location: 5, length: 2)),
        ])
        // Should be sorted by location
        XCTAssertEqual(set.count, 2)
        XCTAssertEqual(set.primary?.range.location, 5)
        XCTAssertEqual(set.selections[1].range.location, 20)
        XCTAssertTrue(set.isMultiCursor)
    }

    // MARK: - Replacing

    func testReplacingPrimary() {
        let original = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 2)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])
        let updated = original.replacingPrimary(
            EditorSelection(range: EditorRange(location: 10, length: 0))
        )
        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.primary?.range.location, 10)
        XCTAssertEqual(updated.selections[1].range.location, 20)
    }

    func testAddingSelection() {
        let original = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
        ])
        let updated = original.addingSelection(
            EditorSelection(range: EditorRange(location: 20, length: 3))
        )
        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.primary?.range.location, 5)
        XCTAssertEqual(updated.selections[1].range.location, 20)
    }

    func testRemovingLastSecondary() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
            EditorSelection(range: EditorRange(location: 30, length: 1)),
        ])
        let updated = set.removingLastSecondary()
        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.selections[1].range.location, 20)
    }

    func testClearingSecondary() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])
        let cleared = set.clearingSecondary()
        XCTAssertEqual(cleared.count, 1)
        XCTAssertEqual(cleared.primary?.range.location, 5)
    }

    // MARK: - Conversion from MultiCursorSelection

    func testFromMultiCursorSelections() {
        let mc: [MultiCursorSelection] = [
            MultiCursorSelection(location: 20, length: 3),
            MultiCursorSelection(location: 5, length: 2),
        ]
        let set = EditorSelectionSet(multiCursorSelections: mc)
        XCTAssertEqual(set.count, 2)
        // Sorted by location
        XCTAssertEqual(set.primary?.range.location, 5)
        XCTAssertEqual(set.selections[1].range.location, 20)
    }

    func testToMultiCursorSelections() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 2)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])
        let mc = set.toMultiCursorSelections()
        XCTAssertEqual(mc.count, 2)
        XCTAssertEqual(mc[0].location, 5)
        XCTAssertEqual(mc[1].location, 20)
    }

    func testRoundTrip() {
        let original: [MultiCursorSelection] = [
            MultiCursorSelection(location: 10, length: 4),
            MultiCursorSelection(location: 30, length: 1),
        ]
        let set = EditorSelectionSet(multiCursorSelections: original)
        let converted = set.toMultiCursorSelections()
        XCTAssertEqual(original, converted)
    }

    func testToMultiCursorState() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 2)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])
        let state = set.toMultiCursorState()
        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(state.all.count, 2)
        XCTAssertEqual(state.primary.location, 5)
    }
}
#endif
