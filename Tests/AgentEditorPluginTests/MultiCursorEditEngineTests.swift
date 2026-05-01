#if canImport(XCTest)
import XCTest
@testable import Lumi

final class MultiCursorEditEngineTests: XCTestCase {
    func testReplaceSelectionAppliesToAllSelections() {
        let result = MultiCursorEditEngine.apply(
            text: "foo bar baz",
            selections: [
                .init(location: 0, length: 3),
                .init(location: 8, length: 3),
            ],
            operation: .replaceSelection("qux")
        )

        XCTAssertEqual(result.text, "qux bar qux")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 3, length: 0),
                .init(location: 11, length: 0),
            ]
        )
    }

    func testDeleteBackwardRemovesSelectionOrPreviousCharacter() {
        let result = MultiCursorEditEngine.apply(
            text: "abcd",
            selections: [
                .init(location: 1, length: 0),
                .init(location: 2, length: 1),
            ],
            operation: .deleteBackward
        )

        XCTAssertEqual(result.text, "bd")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 0, length: 0),
                .init(location: 2, length: 0),
            ]
        )
    }

    func testIndentInsertsIndentAtEachCursor() {
        let result = MultiCursorEditEngine.apply(
            text: "foo\nbar",
            selections: [
                .init(location: 0, length: 0),
                .init(location: 4, length: 0),
            ],
            operation: .indent("    ")
        )

        XCTAssertEqual(result.text, "    foo\n    bar")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 0, length: 0),
                .init(location: 8, length: 0),
            ]
        )
    }

    func testOutdentRemovesLeadingSpacesFromEachLine() {
        let result = MultiCursorEditEngine.apply(
            text: "    foo\n    bar",
            selections: [
                .init(location: 0, length: 0),
                .init(location: 8, length: 0),
            ],
            operation: .outdent(tabSize: 4, useSpaces: true)
        )

        XCTAssertEqual(result.text, "foo\nbar")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 0, length: 0),
                .init(location: 4, length: 0),
            ]
        )
    }
}
#endif
