#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

final class TextEditApplierTests: XCTestCase {
    func testApplyEditsReplacesMultipleRangesFromBackToFront() {
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

        XCTAssertEqual(TextEditApplier.apply(edits: edits, to: text), "omega beta delta")
    }

    func testApplyEditsReturnsNilWhenRangeIsInvalid() {
        let edits: [TextEdit] = [
            .init(
                range: .init(
                    start: .init(line: 10, character: 0),
                    end: .init(line: 10, character: 1)
                ),
                newText: "z"
            ),
        ]

        XCTAssertNil(TextEditApplier.apply(edits: edits, to: "abc"))
    }
}
#endif
