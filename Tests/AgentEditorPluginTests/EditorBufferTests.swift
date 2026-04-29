#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorBufferTests: XCTestCase {
    func testReplaceTextUpdatesSnapshotAndVersion() {
        let buffer = EditorBuffer(text: "hello")

        let result = buffer.replaceText("world")

        XCTAssertEqual(result.snapshot.text, "world")
        XCTAssertEqual(result.snapshot.version, 1)
        XCTAssertEqual(buffer.text, "world")
        XCTAssertEqual(buffer.version, 1)
    }

    func testApplyTransactionReplacesMultipleRangesFromBackToFront() {
        let buffer = EditorBuffer(text: "alpha beta gamma")
        let transaction = EditorTransaction(
            replacements: [
                .init(range: .init(location: 11, length: 5), text: "delta"),
                .init(range: .init(location: 0, length: 5), text: "omega"),
            ]
        )

        let result = buffer.apply(transaction)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.snapshot.text, "omega beta delta")
        XCTAssertEqual(result?.snapshot.version, 1)
    }

    func testApplyTransactionPreservesProvidedSelections() {
        let buffer = EditorBuffer(text: "hello world")
        let transaction = EditorTransaction(
            replacements: [
                .init(range: .init(location: 6, length: 5), text: "swift"),
            ],
            updatedSelections: [
                .init(range: .init(location: 11, length: 0)),
                .init(range: .init(location: 5, length: 0)),
            ]
        )

        let result = buffer.apply(transaction)

        XCTAssertEqual(result?.snapshot.text, "hello swift")
        XCTAssertEqual(
            result?.selections,
            [
                .init(range: .init(location: 11, length: 0)),
                .init(range: .init(location: 5, length: 0)),
            ]
        )
    }

    func testApplyTransactionReturnsNilForInvalidRange() {
        let buffer = EditorBuffer(text: "abc")
        let transaction = EditorTransaction(
            replacements: [
                .init(range: .init(location: 10, length: 1), text: "z"),
            ]
        )

        let result = buffer.apply(transaction)

        XCTAssertNil(result)
        XCTAssertEqual(buffer.text, "abc")
        XCTAssertEqual(buffer.version, 0)
    }
}
#endif
