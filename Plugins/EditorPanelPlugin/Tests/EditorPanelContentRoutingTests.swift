import Foundation
import Testing
@testable import EditorPanelPlugin

/// 期望行为：有 session 但内容尚未 load 时应显示 Loading，而非「不支持的文件」。
@MainActor
struct EditorPanelContentRoutingTests {
    @Test func sessionWithoutLoadedContentRoutesToLoadingNotUnsupported() {
        let sessionID = UUID()
        let snapshot = EditorPanelContentRouting.Snapshot(
            activeSessionID: sessionID,
            currentFileURL: nil,
            canPreview: false,
            isBinaryFile: false,
            isFileLoadInProgress: false,
            fileLoadErrorMessage: nil,
            isMarkdownFile: false,
            isMarkdownPreviewMode: false
        )

        #expect(EditorPanelContentRouting.hasActiveEditorSelection(snapshot))
        #expect(
            EditorPanelContentRouting.resolve(snapshot) == .loading,
            "仅有 session、尚未 load 时应视为加载中，而不是不支持的文件"
        )
    }

    @Test func sessionWithLoadInProgressRoutesToLoadingNotUnsupported() {
        let snapshot = EditorPanelContentRouting.Snapshot(
            activeSessionID: UUID(),
            currentFileURL: nil,
            canPreview: false,
            isBinaryFile: false,
            isFileLoadInProgress: true,
            fileLoadErrorMessage: nil,
            isMarkdownFile: false,
            isMarkdownPreviewMode: false
        )

        #expect(EditorPanelContentRouting.resolve(snapshot) == .loading)
    }

    @Test func loadedUnsupportedFileRoutesToUnsupported() {
        let fileURL = URL(fileURLWithPath: "/tmp/unknown.xyz")
        let snapshot = EditorPanelContentRouting.Snapshot(
            activeSessionID: UUID(),
            currentFileURL: fileURL,
            canPreview: false,
            isBinaryFile: false,
            isFileLoadInProgress: false,
            fileLoadErrorMessage: nil,
            isMarkdownFile: false,
            isMarkdownPreviewMode: false
        )

        #expect(EditorPanelContentRouting.resolve(snapshot) == .unsupported)
    }

    @Test func noSessionAndNoCurrentFileRoutesToEmpty() {
        let snapshot = EditorPanelContentRouting.Snapshot(
            activeSessionID: nil,
            currentFileURL: nil,
            canPreview: false,
            isBinaryFile: false,
            isFileLoadInProgress: false,
            fileLoadErrorMessage: nil,
            isMarkdownFile: false,
            isMarkdownPreviewMode: false
        )

        #expect(!EditorPanelContentRouting.hasActiveEditorSelection(snapshot))
        #expect(EditorPanelContentRouting.resolve(snapshot) == .empty)
    }
}
