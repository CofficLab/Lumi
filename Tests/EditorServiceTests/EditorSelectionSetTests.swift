#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorSelectionSetTests: XCTestCase {
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

    func testMultipleSelectionsAreSortedByLocation() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 20, length: 3)),
            EditorSelection(range: EditorRange(location: 5, length: 2)),
        ])

        XCTAssertEqual(set.count, 2)
        XCTAssertEqual(set.primary?.range.location, 5)
        XCTAssertEqual(set.selections[1].range.location, 20)
        XCTAssertTrue(set.isMultiCursor)
    }

    func testReplacingPrimaryKeepsSecondarySelections() {
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

    func testAddingSelectionPreservesSortedOrder() {
        let original = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])

        let updated = original.addingSelection(
            EditorSelection(range: EditorRange(location: 5, length: 0))
        )

        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.primary?.range.location, 5)
        XCTAssertEqual(updated.selections[1].range.location, 20)
    }

    func testRemovingLastSecondaryDropsTrailingSelection() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
            EditorSelection(range: EditorRange(location: 30, length: 1)),
        ])

        let updated = set.removingLastSecondary()

        XCTAssertEqual(updated.count, 2)
        XCTAssertEqual(updated.selections[1].range.location, 20)
    }

    func testClearingSecondaryKeepsOnlyPrimary() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])

        let cleared = set.clearingSecondary()

        XCTAssertEqual(cleared.count, 1)
        XCTAssertEqual(cleared.primary?.range.location, 5)
    }

    func testRoundTripsMultiCursorSelections() {
        let original: [MultiCursorSelection] = [
            MultiCursorSelection(location: 10, length: 4),
            MultiCursorSelection(location: 30, length: 1),
        ]

        let set = EditorSelectionSet(multiCursorSelections: original)
        let converted = set.toMultiCursorSelections()

        XCTAssertEqual(original, converted)
    }

    func testToMultiCursorStateReflectsPrimaryAndEnabledState() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 2)),
            EditorSelection(range: EditorRange(location: 20, length: 3)),
        ])

        let state = set.toMultiCursorState()

        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(state.all.count, 2)
        XCTAssertEqual(state.primary.location, 5)
    }

    func testReplacingAllFallsBackToInitialForEmptySelections() {
        let original = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 1)),
        ])

        let updated = original.replacingAll([])

        XCTAssertEqual(updated, .initial)
    }

    func testRemovingLastSecondaryLeavesSingleSelectionUntouched() {
        let set = EditorSelectionSet(selections: [
            EditorSelection(range: EditorRange(location: 5, length: 0)),
        ])

        XCTAssertEqual(set.removingLastSecondary(), set)
    }
}
#endif
