#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

final class EditorDocumentControllerTests: XCTestCase {
    func testLoadCreatesBufferAndTextStorage() {
        let controller = EditorDocumentController()

        let result = controller.load(text: "hello")

        XCTAssertEqual(result.snapshot.text, "hello")
        XCTAssertEqual(result.snapshot.version, 0)
        XCTAssertEqual(controller.buffer?.text, "hello")
        XCTAssertEqual(controller.textStorage?.string, "hello")
    }

    func testApplyTransactionUpdatesBufferAndTextStorage() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "alpha beta")
        let transaction = EditorTransaction(
            replacements: [
                .init(range: .init(location: 6, length: 4), text: "swift"),
            ]
        )

        let result = controller.apply(transaction: transaction)

        XCTAssertEqual(result?.snapshot.text, "alpha swift")
        XCTAssertEqual(controller.buffer?.text, "alpha swift")
        XCTAssertEqual(controller.textStorage?.string, "alpha swift")
    }

    func testApplyTextEditsUsesCurrentTextAndSyncsStorage() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "alpha beta")
        let edits: [TextEdit] = [
            .init(
                range: .init(
                    start: .init(line: 0, character: 6),
                    end: .init(line: 0, character: 10)
                ),
                newText: "swift"
            ),
        ]

        let result = controller.applyTextEdits(edits)

        XCTAssertEqual(result?.snapshot.text, "alpha swift")
        XCTAssertEqual(controller.currentText, "alpha swift")
        XCTAssertEqual(controller.textStorage?.string, "alpha swift")
    }

    func testSyncBufferFromTextStorageIfNeededPullsUserEditsBackIntoBuffer() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "before")
        controller.textStorage?.mutableString.setString("after")

        let result = controller.syncBufferFromTextStorageIfNeeded()

        XCTAssertEqual(result?.snapshot.text, "after")
        XCTAssertEqual(controller.buffer?.text, "after")
        XCTAssertEqual(controller.textStorage?.string, "after")
        XCTAssertEqual(controller.buffer?.version, 1)
    }

    func testApplyTextStorageEditUpdatesBufferWithoutFullResync() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "hello world")
        controller.textStorage?.mutableString.setString("hello swift")

        let result = controller.applyTextStorageEdit(
            range: NSRange(location: 6, length: 5),
            text: "swift"
        )

        XCTAssertEqual(result?.snapshot.text, "hello swift")
        XCTAssertEqual(controller.buffer?.text, "hello swift")
        XCTAssertEqual(controller.textStorage?.string, "hello swift")
        XCTAssertEqual(controller.buffer?.version, 1)
    }

    func testClearResetsBufferAndTextStorage() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "hello")

        controller.clear()

        XCTAssertNil(controller.buffer)
        XCTAssertNil(controller.textStorage)
    }
}
#endif
