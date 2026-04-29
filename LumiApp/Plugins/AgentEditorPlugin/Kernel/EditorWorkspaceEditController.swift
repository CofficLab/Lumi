import Foundation
import LanguageServerProtocol

@MainActor
final class EditorWorkspaceEditController {
    @discardableResult
    func apply(
        changes: [String: [TextEdit]]?,
        documentChanges: [WorkspaceEditDocumentChange]?,
        currentURI: String,
        applyCurrentDocumentEdits: (_ edits: [TextEdit], _ reason: String) -> Void,
        applyExternalFileEdits: (_ edits: [TextEdit], _ url: URL) -> Bool
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
                guard let url = URL(string: uri), url.isFileURL else { continue }
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
                    } else if let url = URL(string: uri), url.isFileURL, applyExternalFileEdits(edits, url) {
                        changedFiles += 1
                    }
                case .createFile(let operation):
                    if WorkspaceEditFileOperations.applyCreateFile(operation) {
                        changedFiles += 1
                    }
                case .renameFile(let operation):
                    if WorkspaceEditFileOperations.applyRenameFile(operation) {
                        changedFiles += 1
                    }
                case .deleteFile(let operation):
                    if WorkspaceEditFileOperations.applyDeleteFile(operation) {
                        changedFiles += 1
                    }
                }
            }
        }

        return changedFiles
    }

    func applyTextEditsToFile(_ edits: [TextEdit], url: URL) -> Bool {
        do {
            let original = try String(contentsOf: url, encoding: .utf8)
            guard let updated = TextEditApplier.apply(edits: edits, to: original), updated != original else {
                return false
            }
            try updated.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
