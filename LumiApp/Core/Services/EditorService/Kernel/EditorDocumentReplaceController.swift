import Foundation

struct EditorDocumentReplacePayload {
    let commitPayload: EditorTransactionCommitPayload
}

@MainActor
final class EditorDocumentReplaceController {
    func replaceTextPayload(
        _ text: String,
        documentController: EditorDocumentController,
        transactionController: EditorTransactionController
    ) -> EditorDocumentReplacePayload {
        let result = documentController.replaceText(text)
        return EditorDocumentReplacePayload(
            commitPayload: transactionController.commitPayload(from: result)
        )
    }
}
