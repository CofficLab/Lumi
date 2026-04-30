import Foundation
import LanguageServerProtocol

@MainActor
final class EditorWorkspaceEditController {
    func summarize(
        _ edit: WorkspaceEdit,
        currentURI: String,
        projectRootPath: String?
    ) -> EditorWorkspaceEditSummary {
        var fileLabels: [String] = []
        var seenFiles = Set<String>()
        var changedLocations = 0

        func appendFileLabel(uri: String) {
            guard seenFiles.insert(uri).inserted else { return }
            if uri == currentURI {
                fileLabels.append("Current File")
                return
            }
            guard let url = URL(string: uri), url.isFileURL else {
                fileLabels.append(uri)
                return
            }
            let path = url.standardizedFileURL.path
            if let projectRootPath, !projectRootPath.isEmpty, path.hasPrefix(projectRootPath + "/") {
                fileLabels.append(String(path.dropFirst(projectRootPath.count + 1)))
            } else {
                fileLabels.append(url.lastPathComponent)
            }
        }

        if let changes = edit.changes {
            for (uri, textEdits) in changes where !textEdits.isEmpty {
                appendFileLabel(uri: uri)
                changedLocations += textEdits.count
            }
        }

        if let documentChanges = edit.documentChanges {
            for change in documentChanges {
                switch change {
                case .textDocumentEdit(let item):
                    guard !item.edits.isEmpty else { continue }
                    appendFileLabel(uri: item.textDocument.uri)
                    changedLocations += item.edits.count
                case .createFile(let operation):
                    appendFileLabel(uri: operation.uri)
                    changedLocations += 1
                case .renameFile(let operation):
                    appendFileLabel(uri: operation.oldUri)
                    appendFileLabel(uri: operation.newUri)
                    changedLocations += 1
                case .deleteFile(let operation):
                    appendFileLabel(uri: operation.uri)
                    changedLocations += 1
                }
            }
        }

        return EditorWorkspaceEditSummary(
            changedFiles: fileLabels.count,
            changedLocations: changedLocations,
            fileLabels: Array(fileLabels.prefix(6))
        )
    }

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
