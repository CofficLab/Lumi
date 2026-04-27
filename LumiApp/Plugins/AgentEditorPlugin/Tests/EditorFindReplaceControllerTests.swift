#if canImport(XCTest)
import XCTest
@testable import Lumi

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
                EditorSelection(range: EditorRange(location: 8, length: 3))
            ],
            primarySelection: EditorSelection(range: EditorRange(location: 8, length: 3))
        )

        XCTAssertEqual(result.matches.map(\.range), [
            EditorRange(location: 8, length: 3)
        ])
    }
}
#endif
