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

    func testTransactionForSnippetEditBuildsLinkedPlaceholderSession() {
        let controller = EditorTransactionController()
        let snippet = EditorSnippetParser.parse("func ${1:name}($2) { $1($0) }")

        let payload = controller.transactionForSnippetEdit(
            text: "",
            replacementRange: NSRange(location: 0, length: 0),
            snippet: snippet,
            additionalTextEdits: nil
        )

        XCTAssertEqual(payload?.transaction.replacements.first?.text, "func name() { name() }")
        XCTAssertEqual(
            payload?.transaction.updatedSelections?.map(\.range),
            [EditorRange(location: 5, length: 4), EditorRange(location: 14, length: 4)]
        )
        XCTAssertEqual(payload?.session?.groups.count, 2)
        XCTAssertEqual(payload?.session?.groups.first?.ranges, [
            NSRange(location: 5, length: 4),
            NSRange(location: 14, length: 4),
        ])
        XCTAssertEqual(payload?.session?.groups.last?.ranges, [NSRange(location: 10, length: 0)])
        XCTAssertEqual(payload?.session?.exitSelection, NSRange(location: 19, length: 0))
    }

    func testTransactionForSnippetEditRemapsSessionThroughAdditionalEdits() {
        let controller = EditorTransactionController()
        let snippet = EditorSnippetParser.parse("${1:foo}")
        let additionalTextEdits: [TextEdit] = [
            .init(
                range: .init(
                    start: .init(line: 0, character: 0),
                    end: .init(line: 0, character: 0)
                ),
                newText: "let "
            )
        ]

        let payload = controller.transactionForSnippetEdit(
            text: "bar",
            replacementRange: NSRange(location: 0, length: 3),
            snippet: snippet,
            additionalTextEdits: additionalTextEdits
        )

        XCTAssertEqual(payload?.session?.groups.first?.ranges, [NSRange(location: 4, length: 3)])
        XCTAssertEqual(payload?.session?.exitSelection, NSRange(location: 7, length: 0))
        XCTAssertEqual(payload?.transaction.updatedSelections?.first?.range, EditorRange(location: 4, length: 3))
    }
}
#endif
