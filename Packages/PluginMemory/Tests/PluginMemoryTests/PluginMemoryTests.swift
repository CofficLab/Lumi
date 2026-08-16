import Foundation
import Testing
import KernelCore
import AgentToolKit
import ProviderStorage
import ProviderToolManager

@testable import PluginMemory

@Suite("MemoryPlugin")
@MainActor
struct MemoryPluginTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-tests-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    @Test("存储保存并读取记忆")
    func saveAndLoad() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await storage.save(
            id: "user-role",
            type: .user,
            name: "User Role",
            description: "用户角色",
            content: "规则内容",
            scope: .global,
            projectPath: nil
        )
        let item = try await storage.load(id: "user-role", type: .user, scope: .global, projectPath: nil)
        #expect(item != nil)
        #expect(item?.name == "User Role")
        #expect(item?.content.contains("规则内容") == true)
        #expect(item?.type == .user)
    }

    @Test("存储更新保留 createdAt")
    func saveUpdatesPreservesCreatedAt() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try await storage.save(
            id: "fb-1", type: .feedback, name: "N", description: "d",
            content: "v1", scope: .global, projectPath: nil
        )
        let second = try await storage.save(
            id: "fb-1", type: .feedback, name: "N", description: "d",
            content: "v2", scope: .global, projectPath: nil
        )
        #expect(abs(second.createdAt.timeIntervalSince(first.createdAt)) < 1.0)
        #expect(second.content.contains("v2"))
    }

    @Test("存储列出与删除")
    func listAndDelete() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try await storage.save(
            id: "a", type: .project, name: "A", description: "",
            content: "x", scope: .project, projectPath: "/tmp/proj"
        )
        _ = try await storage.save(
            id: "b", type: .reference, name: "B", description: "",
            content: "y", scope: .project, projectPath: "/tmp/proj"
        )
        let items = await storage.list(scope: .project, projectPath: "/tmp/proj")
        #expect(items.count == 2)

        try await storage.delete(id: "a", scope: .project, projectPath: "/tmp/proj")
        let after = await storage.list(scope: .project, projectPath: "/tmp/proj")
        #expect(after.count == 1)
        #expect(after.first?.id == "b")
    }

    @Test("SaveMemoryTool 保存并返回成功")
    func saveTool() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = SaveMemoryTool(storage: storage, project: nil)
        let result = try await tool.execute(arguments: [
            "id": ToolArgument("test-mem"),
            "name": ToolArgument("Test"),
            "content": ToolArgument("内容"),
        ])
        #expect(result.contains("Memory Saved"))
        let item = try await storage.load(id: "test-mem", type: .project, scope: .global, projectPath: nil)
        #expect(item != nil)
    }

    @Test("RecallMemoryTool 未找到返回提示")
    func recallToolNotFound() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = RecallMemoryTool(storage: storage, project: nil)
        let result = try await tool.execute(arguments: ["id": ToolArgument("nonexistent")])
        #expect(result.contains("Not Found"))
    }

    @Test("插件注册 4 个记忆工具")
    func pluginRegistersTools() throws {
        let kernel = KernelCoreContainer()
        let storage = DefaultStorageProvider()
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any StorageProviding).self, storage)
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        let plugin = MemoryPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(toolManager.tool(named: "save_memory") != nil)
        #expect(toolManager.tool(named: "recall_memory") != nil)
        #expect(toolManager.tool(named: "list_memories") != nil)
        #expect(toolManager.tool(named: "delete_memory") != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(toolManager.tool(named: "save_memory") == nil)
    }
}
