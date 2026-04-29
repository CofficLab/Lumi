#if canImport(XCTest)
import XCTest
@testable import Lumi

final class MultiCursorTransactionBuilderTests: XCTestCase {
    func testReplaceSelectionBuildsReplacementsForEverySelection() {
        let transaction = MultiCursorTransactionBuilder.makeTransaction(
            operation: .replaceSelection("x"),
            selections: [
                .init(location: 0, length: 3),
                .init(location: 8, length: 3),
            ],
            updatedSelections: [
                .init(location: 1, length: 0),
                .init(location: 9, length: 0),
            ]
        )

        XCTAssertEqual(
            transaction.replacements,
            [
                .init(range: .init(location: 0, length: 3), text: "x"),
                .init(range: .init(location: 8, length: 3), text: "x"),
            ]
        )
        XCTAssertEqual(
            transaction.updatedSelections,
            [
                .init(range: .init(location: 1, length: 0)),
                .init(range: .init(location: 9, length: 0)),
            ]
        )
    }

    func testDeleteBackwardBuildsCorrectReplacementRanges() {
        let transaction = MultiCursorTransactionBuilder.makeTransaction(
            operation: .deleteBackward,
            selections: [
                .init(location: 4, length: 0),
                .init(location: 6, length: 2),
                .init(location: 0, length: 0),
            ],
            updatedSelections: []
        )

        XCTAssertEqual(
            transaction.replacements,
            [
                .init(range: .init(location: 3, length: 1), text: ""),
                .init(range: .init(location: 6, length: 2), text: ""),
                .init(range: .init(location: 0, length: 0), text: ""),
            ]
        )
    }
}
#endif
