import Foundation

public struct EditorDocumentReplacePayload {
    public let commitPayload: EditorTransactionCommitPayload

    public init(commitPayload: EditorTransactionCommitPayload) {
        self.commitPayload = commitPayload
    }
}

@MainActor
public final class EditorDocumentReplaceController {
    public init() {}

    public func replaceTextPayload(
        _ text: String,
        replaceText: (String) -> EditorEditResult,
        transactionController: EditorTransactionController
    ) -> EditorDocumentReplacePayload {
        let result = replaceText(text)
        return EditorDocumentReplacePayload(
            commitPayload: transactionController.commitPayload(from: result)
        )
    }
}
