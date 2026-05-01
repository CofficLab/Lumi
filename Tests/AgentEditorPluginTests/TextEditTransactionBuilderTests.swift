#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

final class TextEditTransactionBuilderTests: XCTestCase {
    func testBuildsTransactionForMultipleEdits() {
        let text = "alpha beta gamma"
        let edits: [TextEdit] = [
            .init(
                range: .init(
                    start: .init(line: 0, character: 0),
                    end: .init(line: 0, character: 5)
                ),
                newText: "omega"
            ),
            .init(
                range: .init(
                    start: .init(line: 0, character: 11),
                    end: .init(line: 0, character: 16)
                ),
                newText: "delta"
            ),
        ]

        let transaction = TextEditTransactionBuilder.makeTransaction(edits: edits, in: text)

        XCTAssertEqual(
            transaction?.replacements,
            [
                .init(range: .init(location: 0, length: 5), text: "omega"),
                .init(range: .init(location: 11, length: 5), text: "delta"),
            ]
        )
    }

    func testReturnsNilForOutOfBoundsEdit() {
        let text = "abc"
        let edits: [TextEdit] = [
            .init(
                range: .init(
                    start: .init(line: 3, character: 0),
                    end: .init(line: 3, character: 1)
                ),
                newText: "z"
            ),
        ]

        XCTAssertNil(TextEditTransactionBuilder.makeTransaction(edits: edits, in: text))
    }
}
#endif
