import EditorService
import Foundation
import Testing
@testable import EditorPanelPlugin

/// 期望行为：Tab 恢复阶段 1 的 session-only 状态应路由到 Loading，而不是「不支持的文件」。
@MainActor
struct EditorTabRestoreContentRoutingTests {
    @Test func sessionOnlyRestoreSnapshotRoutesToLoadingNotUnsupported() {
        let service = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let file = makeTempSwiftFile(named: "Routed.swift")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        _ = service.sessions.openFile(at: file)

        let snapshot = EditorPanelContentRouting.Snapshot(
            activeSessionID: service.sessions.activeSessionID,
            currentFileURL: service.files.currentFileURL,
            canPreview: service.files.canPreview,
            isBinaryFile: service.files.isBinaryFile,
            isFileLoadInProgress: service.files.isFileLoadInProgress,
            fileLoadErrorMessage: service.files.fileLoadErrorMessage,
            isMarkdownFile: service.files.isMarkdownFile,
            isMarkdownPreviewMode: service.isMarkdownPreviewMode
        )

        #expect(
            EditorPanelContentRouting.resolve(snapshot) == .loading,
            "openFile(session-only) 后、open(at:) 完成前，UI 应显示加载中"
        )
    }
}

@MainActor
private func makeTempSwiftFile(named name: String) -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-routing-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent(name)
    try? "let routed = true\n".write(to: file, atomically: true, encoding: .utf8)
    return file
}
