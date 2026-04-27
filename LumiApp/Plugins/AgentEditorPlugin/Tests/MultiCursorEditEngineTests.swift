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

        XCTAssertEqual(result.text, "ad")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 0, length: 0),
                .init(location: 1, length: 0),
            ]
        )
    }
}
#endif
