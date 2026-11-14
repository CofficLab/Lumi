import EditorKernel
import Foundation
import Testing
@testable import EditorService

/// 回归 #206：外部文件异步重读返回后必须复核当前标签。
///
/// 文件 watcher 为 A 启动异步重读后，若用户在磁盘读取期间切到 B，
/// 续体不得把 A 的内容写进 B 的编辑器状态（否则随后保存会损坏 B）。
@MainActor
struct EditorExternalReloadIdentityTests {

    private func makeState(text: String) -> EditorState {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        _ = state.documentController.load(text: text)
        state.content = state.documentController.textStorage
        state.hasUnsavedChanges = false
        return state
    }

    private func makeTempFile(_ contents: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-206-\(UUID().uuidString).txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("切到 B 后 A 的外部重读结果被丢弃（回归 #206）")
    func externalReloadDiscardedAfterTabSwitch() async throws {
        let fileA = try makeTempFile("A-external")
        defer { try? FileManager.default.removeItem(at: fileA) }
        let fileB = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-206-B-\(UUID().uuidString).txt")

        let state = makeState(text: "A-original")
        state.testing_setCurrentFileURL(fileA)

        // 启动 A 的异步外部重读（同步捕获 A-original 后spawn Task）。
        state.reloadIfFileChangedExternally(url: fileA, currentModDate: Date())

        // 在重读返回前切到 B：同步执行，不让出主 actor，
        // 保证续体恢复时 currentFileURL 已指向 B。
        state.testing_setCurrentFileURL(fileB)
        _ = state.documentController.load(text: "B-original")
        state.content = state.documentController.textStorage
        state.hasUnsavedChanges = false

        // 让 A 的 detached 磁盘读取与主 actor 续体执行完成。
        try await Task.sleep(for: .milliseconds(400))

        #expect(state.currentFileURL == fileB)
        #expect(state.content?.string == "B-original")
    }

    @Test("仍停留在 A 时外部重读正常应用（回归 #206）")
    func externalReloadAppliedWhenStillSameFile() async throws {
        let fileA = try makeTempFile("A-external")
        defer { try? FileManager.default.removeItem(at: fileA) }

        let state = makeState(text: "A-original")
        state.testing_setCurrentFileURL(fileA)

        state.reloadIfFileChangedExternally(url: fileA, currentModDate: Date())

        try await Task.sleep(for: .milliseconds(400))

        #expect(state.currentFileURL == fileA)
        #expect(state.content?.string == "A-external")
    }
}