#if canImport(XCTest)
import EditorKernelCore
import XCTest
@testable import EditorService

final class EditorFindReplaceControllerTests: XCTestCase {
    func testMatchesPlainTextCaseInsensitive() {
        let state = EditorFindReplaceState(findText: "foo")

        let result = EditorFindReplaceController.matches(
            in: "Foo foo FOO",
            state: state,
            selections: [],
            primarySelection: nil
        )

        XCTAssertEqual(result.matches.count, 3)
        XCTAssertEqual(result.selectedMatchIndex, 0)
        XCTAssertEqual(result.selectedMatchRange, EditorRange(location: 0, length: 3))
    }

    func testMatchesWholeWordSkipsSubstrings() {
        let state = EditorFindReplaceState(
            findText: "cat",
            options: EditorFindReplaceOptions(matchesWholeWord: true)
        )

        let result = EditorFindReplaceController.matches(
            in: "cat concatenate cat",
            state: state,
            selections: [],
            primarySelection: nil
        )

        XCTAssertEqual(result.matches.map(\.range), [
            EditorRange(location: 0, length: 3),
            EditorRange(location: 16, length: 3),
        ])
    }

    func testMatchesInSelectionOnlyUsesNonEmptySelections() {
        let state = EditorFindReplaceState(
            findText: "foo",
            options: EditorFindReplaceOptions(inSelectionOnly: true)
        )

        let result = EditorFindReplaceController.matches(
            in: "foo bar foo baz",
            state: state,
            selections: [
                EditorSelection(range: EditorRange(location: 8, length: 3)),
            ],
            primarySelection: EditorSelection(range: EditorRange(location: 8, length: 3))
        )

        XCTAssertEqual(result.matches.map(\.range), [
            EditorRange(location: 8, length: 3),
        ])
    }

    func testMatchesInSelectionOnlyUsesAllNonEmptySelectionsInMultiSelectionMode() {
        let state = EditorFindReplaceState(
            findText: "foo",
            options: EditorFindReplaceOptions(inSelectionOnly: true)
        )

        let result = EditorFindReplaceController.matches(
            in: "foo bar foo baz foo",
            state: state,
            selections: [
                EditorSelection(range: EditorRange(location: 0, length: 3)),
                EditorSelection(range: EditorRange(location: 8, length: 3)),
                EditorSelection(range: EditorRange(location: 16, length: 3)),
            ],
            primarySelection: EditorSelection(range: EditorRange(location: 8, length: 3))
        )

        XCTAssertEqual(result.matches.map(\.range), [
            EditorRange(location: 0, length: 3),
            EditorRange(location: 8, length: 3),
            EditorRange(location: 16, length: 3),
        ])
    }

    func testMatchesInSelectionOnlyFallsBackToPrimarySelectionWhenSelectionsAreEmpty() {
        let state = EditorFindReplaceState(
            findText: "foo",
            options: EditorFindReplaceOptions(inSelectionOnly: true)
        )

        let result = EditorFindReplaceController.matches(
            in: "foo bar foo baz",
            state: state,
            selections: [
                EditorSelection(range: EditorRange(location: 0, length: 0)),
            ],
            primarySelection: EditorSelection(range: EditorRange(location: 8, length: 3))
        )

        XCTAssertEqual(result.matches.map(\.range), [
            EditorRange(location: 8, length: 3),
        ])
    }

    func testMatchesPreferSelectedMatchRangeWhenPresent() {
        var state = EditorFindReplaceState(findText: "foo")
        state.selectedMatchRange = EditorRange(location: 4, length: 3)

        let result = EditorFindReplaceController.matches(
            in: "foo foo foo",
            state: state,
            selections: [],
            primarySelection: EditorSelection(range: EditorRange(location: 0, length: 0))
        )

        XCTAssertEqual(result.selectedMatchIndex, 1)
        XCTAssertEqual(result.selectedMatchRange, EditorRange(location: 4, length: 3))
    }

    func testMatchesPickContainingMatchForPrimarySelection() {
        let state = EditorFindReplaceState(findText: "foo")

        let result = EditorFindReplaceController.matches(
            in: "foo bar foo baz",
            state: state,
            selections: [],
            primarySelection: EditorSelection(range: EditorRange(location: 9, length: 0))
        )

        XCTAssertEqual(result.selectedMatchIndex, 1)
        XCTAssertEqual(result.selectedMatchRange, EditorRange(location: 8, length: 3))
    }

    func testMatchesPickNextMatchAfterPrimarySelectionWhenNotInsideMatch() {
        let state = EditorFindReplaceState(findText: "foo")

        let result = EditorFindReplaceController.matches(
            in: "foo bar foo baz foo",
            state: state,
            selections: [],
            primarySelection: EditorSelection(range: EditorRange(location: 5, length: 0))
        )

        XCTAssertEqual(result.selectedMatchIndex, 1)
        XCTAssertEqual(result.selectedMatchRange, EditorRange(location: 8, length: 3))
    }

    func testNextAndPreviousMatchIndexWrapAround() {
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 3), matchedText: "foo"),
            EditorFindMatch(range: EditorRange(location: 4, length: 3), matchedText: "foo"),
            EditorFindMatch(range: EditorRange(location: 8, length: 3), matchedText: "foo"),
        ]

        XCTAssertEqual(EditorFindReplaceController.nextMatchIndex(in: matches, selectedMatchIndex: nil), 0)
        XCTAssertEqual(EditorFindReplaceController.nextMatchIndex(in: matches, selectedMatchIndex: 2), 0)
        XCTAssertEqual(EditorFindReplaceController.previousMatchIndex(in: matches, selectedMatchIndex: nil), 2)
        XCTAssertEqual(EditorFindReplaceController.previousMatchIndex(in: matches, selectedMatchIndex: 0), 2)
    }
}
#endif
