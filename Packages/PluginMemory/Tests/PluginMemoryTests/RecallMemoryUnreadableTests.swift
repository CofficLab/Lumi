import Foundation
import Testing
import KitAgentTool

@testable import PluginMemory

/// 回归 #788：`recall_memory` 把「文件存在但不可读 / UTF-8 非法」误报为「不存在」。
/// `MemoryFileStorage.load` 旧实现用 `try?` 吞掉读取错误并返回 nil，工具据此报 not found，
/// Agent 可能因此重建或覆盖既有记忆（数据丢失）。只有文件确实不存在时才允许 not found；
/// 存在但读取失败必须作为存储/工具失败抛出。
@Suite("RecallMemory 不可读存储")
@MainActor
struct RecallMemoryUnreadableTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-unreadable-tests-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    private func makeTool(_ storage: MemoryFileStorage) -> RecallMemoryTool {
        RecallMemoryTool(storage: storage, projectCapability: MemoryProjectCapabilityAdapter(project: nil))
    }

    @Test("存在但 UTF-8 非法的记忆文件：load 抛出 storageUnavailable 而非返回 nil")
    func loadThrowsOnInvalidUTF8() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("global/demo.md")
        try Data([0xFF, 0xFE, 0xFD]).write(to: fileURL)

        do {
            let item = try await storage.load(id: "demo", type: .project, scope: .global, projectPath: nil)
            Issue.record("存在但不可读的文件必须抛出，而非返回 \(String(describing: item))")
        } catch let error as MemoryError {
            guard case .storageUnavailable = error else {
                Issue.record("期望 storageUnavailable，实际 \(error)")
                return
            }
        }
    }

    @Test("recall_memory 对不可读记忆报告存储失败，而非误报 not found")
    func recallReportsStorageFailureNotNotFound() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("global/demo.md")
        try Data([0xFF, 0xFE, 0xFD]).write(to: fileURL)
        let tool = makeTool(storage)

        do {
            _ = try await tool.execute(arguments: [
                "id": ToolArgument("demo"),
                "scope": ToolArgument("global"),
            ])
            Issue.record("不可读记忆必须抛出工具错误")
        } catch let error as ToolExecutionError {
            let desc = error.errorDescription ?? ""
            #expect(desc.contains("storage unavailable"), "应报告存储不可读：\(desc)")
            #expect(!desc.lowercased().contains("not found"), "不得误报为不存在：\(desc)")
        }
    }

    @Test("文件确实不存在时 load 返回 nil 且 recall 仍报 not found")
    func absentFileStillReportsNotFound() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let loaded = try await storage.load(id: "ghost", type: .project, scope: .global, projectPath: nil)
        #expect(loaded == nil)

        let tool = makeTool(storage)
        do {
            _ = try await tool.execute(arguments: [
                "id": ToolArgument("ghost"),
                "scope": ToolArgument("global"),
            ])
            Issue.record("不存在的记忆必须抛出 not found")
        } catch let error as ToolExecutionError {
            #expect((error.errorDescription ?? "").lowercased().contains("not found"))
        }
    }

    #if os(macOS)
    @Test("存在但无读权限的记忆文件：load 抛出 storageUnavailable")
    func loadThrowsOnNoReadPermission() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await storage.save(
            id: "perm", type: .project, name: "N", description: "d",
            content: "v", scope: .global, projectPath: nil
        )
        let fileURL = root.appendingPathComponent("global/perm.md")
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0)], ofItemAtPath: fileURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o644)], ofItemAtPath: fileURL.path)
        }

        do {
            let item = try await storage.load(id: "perm", type: .project, scope: .global, projectPath: nil)
            Issue.record("无读权限的文件必须抛出，而非返回 \(String(describing: item))")
        } catch let error as MemoryError {
            guard case .storageUnavailable = error else {
                Issue.record("期望 storageUnavailable，实际 \(error)")
                return
            }
        }
    }
    #endif
}