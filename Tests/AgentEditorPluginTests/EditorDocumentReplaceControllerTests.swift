#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorDocumentReplaceControllerTests: XCTestCase {
    func testReplaceTextPayloadUsesTransactionCommitPayload() {
        let controller = EditorDocumentReplaceController()
        let documentController = EditorDocumentController()
        let transactionController = EditorTransactionController()
        _ = documentController.load(text: "old")

        let payload = controller.replaceTextPayload(
            "new\ntext",
            documentController: documentController,
            transactionController: transactionController
        )

        XCTAssertEqual(payload.commitPayload.text, "new\ntext")
        XCTAssertEqual(payload.commitPayload.totalLines, 2)
    }
}
#endif
