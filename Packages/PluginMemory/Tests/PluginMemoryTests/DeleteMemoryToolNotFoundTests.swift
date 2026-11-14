import Foundation
import Testing
import KitAgentTool

@testable import PluginMemory

/// 回归 #809：`delete_memory` 对不存在的 ID 也返回 `Memory Deleted` 成功文案，
/// 模型无法区分真实删除与无效操作（重复删除同一 ID 同样报成功）。
/// 目标不存在时必须抛出工具错误，只有真正删除了已存在的记忆才报成功。
@Suite("DeleteMemoryTool 不存在目标")
@MainActor
struct DeleteMemoryToolNotFoundTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-delete-tests-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    @Test("删除不存在的记忆必须抛出错误而非报成功")
    func deletingMissingMemoryThrows() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = DeleteMemoryTool(storage: storage, projectCapability: MemoryProjectCapabilityAdapter(project: nil))
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "id": ToolArgument("definitely-missing"),
                "scope": ToolArgument("global"),
            ])
        }
    }

    @Test("重复删除同一 ID：首次成功，第二次必须报错")
    func secondDeleteOfSameIDThrows() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await storage.save(
            id: "once", type: .feedback, name: "N", description: "d",
            content: "v", scope: .global, projectPath: nil
        )
        let tool = DeleteMemoryTool(storage: storage, projectCapability: MemoryProjectCapabilityAdapter(project: nil))
        let arguments: [String: ToolArgument] = [
            "id": ToolArgument("once"),
            "scope": ToolArgument("global"),
        ]

        let first = try await tool.execute(arguments: arguments)
        #expect(first.contains("Memory Deleted"))
        #expect(try await storage.load(id: "once", type: .feedback, scope: .global, projectPath: nil) == nil)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: arguments)
        }
    }

    @Test("存储层删除不存在的记忆抛出 notFound")
    func storageDeleteMissingThrowsNotFound() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        await #expect(throws: MemoryError.notFound("ghost")) {
            try await storage.delete(id: "ghost", scope: .global, projectPath: nil)
        }
    }
}