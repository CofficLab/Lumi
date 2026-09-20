import Foundation
import LanguageServerProtocol

@MainActor
public final class EditorWorkspaceEditController {
    public init() {}

    public func summarize(
        _ edit: WorkspaceEdit,
        currentURI: String,
        projectRootPath: String?
    ) -> EditorWorkspaceEditSummary {
        EditorWorkspaceEditSummaryBuilder.summarize(
            edit,
            currentURI: currentURI,
            projectRootPath: projectRootPath
        )
    }

    @discardableResult
    public func apply(
        changes: [String: [TextEdit]]?,
        documentChanges: [WorkspaceEditDocumentChange]?,
        currentURI: String,
        applyCurrentDocumentEdits: (_ edits: [TextEdit], _ reason: String) -> Void,
        applyExternalFileEdits: (_ edits: [TextEdit], _ url: URL) -> Bool,
        applyCreateFile: (_ operation: CreateFile) -> Bool,
        applyRenameFile: (_ operation: RenameFile) -> Bool,
        applyDeleteFile: (_ operation: DeleteFile) -> Bool
    ) -> Int {
        var changedFiles = 0

        if let changes, !changes.isEmpty {
            for (uri, textEdits) in changes {
                guard !textEdits.isEmpty else { continue }
                if uri == currentURI {
                    applyCurrentDocumentEdits(textEdits, "lsp_workspace_edit")
                    changedFiles += 1
                    continue
                }
                guard let url = WorkspaceEditFileOperations.fileURL(from: uri) else { continue }
                if applyExternalFileEdits(textEdits, url) {
                    changedFiles += 1
                }
            }
        }

        if let documentChanges {
            for change in documentChanges {
                switch change {
                case .textDocumentEdit(let item):
                    let uri = item.textDocument.uri
                    let edits = item.edits
                    guard !edits.isEmpty else { continue }

                    if uri == currentURI {
                        applyCurrentDocumentEdits(edits, "lsp_document_edit")
                        changedFiles += 1
                    } else if let url = WorkspaceEditFileOperations.fileURL(from: uri), applyExternalFileEdits(edits, url) {
                        changedFiles += 1
                    }
                case .createFile(let operation):
                    if applyCreateFile(operation) {
                        changedFiles += 1
                    }
                case .renameFile(let operation):
                    if applyRenameFile(operation) {
                        changedFiles += 1
                    }
                case .deleteFile(let operation):
                    if applyDeleteFile(operation) {
                        changedFiles += 1
                    }
                }
            }
        }

        return changedFiles
    }

    public func applyTextEditsToFile(_ edits: [TextEdit], url: URL) -> Bool {
        do {
            var encoding = String.Encoding.utf8
            let original = try String(contentsOf: url, usedEncoding: &encoding)
            guard let updated = TextEditApplier.apply(edits: edits, to: original), updated != original else {
                return false
            }
            try updated.write(to: url, atomically: true, encoding: encoding)
            return true
        } catch {
            return false
        }
    }
}
