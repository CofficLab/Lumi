import Foundation
import LanguageServerProtocol

struct EditorWorkspaceEditSummary: Equatable {
    let changedFiles: Int
    let changedLocations: Int
    let fileLabels: [String]

    var summaryText: String {
        "\(changedLocations) changes in \(changedFiles) files"
    }
}

struct EditorInlineRenameState {
    let originalName: String
    var draftName: String
    var isLoadingPreview: Bool
    var errorMessage: String?
    var previewSummary: EditorWorkspaceEditSummary?
    var previewEdit: WorkspaceEdit?

    var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canPreview: Bool {
        !trimmedDraftName.isEmpty && trimmedDraftName != originalName
    }

    var canApply: Bool {
        previewEdit != nil && previewSummary != nil && !isLoadingPreview
    }

    mutating func invalidatePreview() {
        errorMessage = nil
        previewSummary = nil
        previewEdit = nil
    }
}
