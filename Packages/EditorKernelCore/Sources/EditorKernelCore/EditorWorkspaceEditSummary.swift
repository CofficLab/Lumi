import Foundation
import LanguageServerProtocol

public struct EditorWorkspaceEditSummary: Equatable {
    public let changedFiles: Int
    public let changedLocations: Int
    public let fileLabels: [String]

    public var summaryText: String {
        "\(changedLocations) changes in \(changedFiles) files"
    }

    public init(changedFiles: Int, changedLocations: Int, fileLabels: [String]) {
        self.changedFiles = changedFiles
        self.changedLocations = changedLocations
        self.fileLabels = fileLabels
    }
}

public struct EditorInlineRenameState {
    public let originalName: String
    public var draftName: String
    public var isLoadingPreview: Bool
    public var errorMessage: String?
    public var previewSummary: EditorWorkspaceEditSummary?
    public var previewEdit: WorkspaceEdit?

    public var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canPreview: Bool {
        !trimmedDraftName.isEmpty && trimmedDraftName != originalName
    }

    public var canApply: Bool {
        previewEdit != nil && previewSummary != nil && !isLoadingPreview
    }

    public init(
        originalName: String,
        draftName: String,
        isLoadingPreview: Bool,
        errorMessage: String?,
        previewSummary: EditorWorkspaceEditSummary?,
        previewEdit: WorkspaceEdit?
    ) {
        self.originalName = originalName
        self.draftName = draftName
        self.isLoadingPreview = isLoadingPreview
        self.errorMessage = errorMessage
        self.previewSummary = previewSummary
        self.previewEdit = previewEdit
    }

    public mutating func invalidatePreview() {
        errorMessage = nil
        previewSummary = nil
        previewEdit = nil
    }
}

public enum EditorWorkspaceEditSummaryBuilder {
    public static func summarize(
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
}
