#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorTransactionControllerTests: XCTestCase {
    func testTransactionForInputEditBuildsSelectionAwareTransaction() {
        let controller = EditorTransactionController()

        let transaction = controller.transactionForInputEdit(
            replacementRange: NSRange(location: 2, length: 1),
            replacementText: "abc",
            selectedRanges: [NSRange(location: 5, length: 0)]
        )

        XCTAssertEqual(transaction?.replacements.first?.range.location, 2)
        XCTAssertEqual(transaction?.replacements.first?.range.length, 1)
        XCTAssertEqual(transaction?.replacements.first?.text, "abc")
        XCTAssertEqual(transaction?.updatedSelections?.first?.range.location, 5)
    }

    func testTransactionForCompletionEditRemapsCursorToInsertedSuffix() {
        let controller = EditorTransactionController()

        let transaction = controller.transactionForCompletionEdit(
            text: "pri",
            replacementRange: NSRange(location: 0, length: 3),
            replacementText: "print",
            additionalTextEdits: nil
        )

        XCTAssertEqual(transaction?.updatedSelections?.first?.range.location, 5)
        XCTAssertEqual(transaction?.updatedSelections?.first?.range.length, 0)
    }

    func testCommitPayloadBuildsCanonicalSelectionSet() {
        let controller = EditorTransactionController()
        let result = EditorEditResult(
            snapshot: EditorSnapshot(text: "a\nb", version: 3),
            selections: [EditorSelection(range: EditorRange(location: 1, length: 0))]
        )

        let payload = controller.commitPayload(from: result)

        XCTAssertEqual(payload.totalLines, 2)
        XCTAssertEqual(payload.version, 3)
        XCTAssertEqual(payload.text, "a\nb")
        XCTAssertEqual(payload.canonicalSelectionSet?.selections.count, 1)
        XCTAssertEqual(payload.multiCursorSelections?.first?.location, 1)
    }
}
#endif
