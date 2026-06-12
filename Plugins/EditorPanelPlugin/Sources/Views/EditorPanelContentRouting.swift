import Foundation

/// 编辑器主内容区路由决策（从 `EditorPanelView.editorContent` 提取，供单元测试断言期望行为）。
enum EditorPanelContentRouting {
    enum Kind: Equatable {
        case empty
        case loading
        case sourceEditor
        case markdownPreview
        case binaryPreview
        case loadFailure
        case unsupported
    }

    struct Snapshot: Equatable {
        var activeSessionID: UUID?
        var currentFileURL: URL?
        var canPreview: Bool
        var isBinaryFile: Bool
        var isFileLoadInProgress: Bool
        var fileLoadErrorMessage: String?
        var isMarkdownFile: Bool
        var isMarkdownPreviewMode: Bool
    }

    static func hasActiveEditorSelection(_ snapshot: Snapshot) -> Bool {
        snapshot.activeSessionID != nil || snapshot.currentFileURL != nil
    }

    static func resolve(_ snapshot: Snapshot) -> Kind {
        guard hasActiveEditorSelection(snapshot) else {
            return .empty
        }

        if snapshot.isMarkdownFile {
            return snapshot.isMarkdownPreviewMode ? .markdownPreview : .sourceEditor
        }
        if snapshot.canPreview {
            return .sourceEditor
        }
        if snapshot.isBinaryFile, snapshot.currentFileURL != nil {
            return .binaryPreview
        }
        if snapshot.isFileLoadInProgress {
            return .loading
        }
        if snapshot.activeSessionID != nil, snapshot.currentFileURL == nil {
            return .loading
        }
        if snapshot.fileLoadErrorMessage != nil {
            return .loadFailure
        }
        if snapshot.currentFileURL != nil {
            return .unsupported
        }
        return .loading
    }
}
