import Foundation
import Testing
import KernelCore
import KitAgentTool
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

        let tool = SaveMemoryTool(storage: storage, projectCapability: MemoryProjectCapabilityAdapter(project: nil))
        let result = try await tool.execute(arguments: [
            "id": ToolArgument("test-mem"),
            "name": ToolArgument("Test"),
            "content": ToolArgument("内容"),
        ])
        #expect(result.contains("Memory Saved"))
        let item = try await storage.load(id: "test-mem", type: .project, scope: .global, projectPath: nil)
        #expect(item != nil)
    }

    @Test("RecallMemoryTool 未找到时抛出错误")
    func recallToolNotFound() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let tool = RecallMemoryTool(storage: storage, projectCapability: MemoryProjectCapabilityAdapter(project: nil))
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["id": ToolArgument("nonexistent")])
        }
    }

    @Test("不同 ID 编码后不碰撞：保存、召回、删除互不影响")
    func distinctIDsDoNotCollide() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try await storage.save(
            id: "a b", type: .project, name: "A", description: "",
            content: "content-A", scope: .global, projectPath: nil
        )
        let second = try await storage.save(
            id: "a@b", type: .project, name: "B", description: "",
            content: "content-B", scope: .global, projectPath: nil
        )
        // 字面量百分号 ID 也不能与编码结果撞车。
        let third = try await storage.save(
            id: "a%20b", type: .project, name: "C", description: "",
            content: "content-C", scope: .global, projectPath: nil
        )

        #expect(first.filePath != second.filePath)
        #expect(third.filePath != first.filePath)

        #expect(try await storage.load(id: "a b", type: .project, scope: .global, projectPath: nil)?.content == "content-A")
        #expect(try await storage.load(id: "a@b", type: .project, scope: .global, projectPath: nil)?.content == "content-B")
        #expect(try await storage.load(id: "a%20b", type: .project, scope: .global, projectPath: nil)?.content == "content-C")

        let listed = await storage.list(scope: .global, projectPath: nil)
        #expect(Set(listed.map(\.id)) == ["a b", "a@b", "a%20b"])

        try await storage.delete(id: "a b", scope: .global, projectPath: nil)
        #expect(try await storage.load(id: "a b", type: .project, scope: .global, projectPath: nil) == nil)
        #expect(try await storage.load(id: "a@b", type: .project, scope: .global, projectPath: nil)?.content == "content-B")
    }

    @Test("不同 project 路径编码后不碰撞：保存、召回、删除互不影响")
    func distinctProjectPathsDoNotCollide() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        // "/tmp/a b" 与 "/tmp/a-b" 在旧的有损映射下都会变成 "/tmp/a-b"，
        // 两个项目共用同一记忆目录，互相覆盖、召回与删除（#197）。
        let first = try await storage.save(
            id: "architecture", type: .project, name: "A", description: "",
            content: "content-A", scope: .project, projectPath: "/tmp/a b"
        )
        let second = try await storage.save(
            id: "architecture", type: .project, name: "B", description: "",
            content: "content-B", scope: .project, projectPath: "/tmp/a-b"
        )

        #expect(first.filePath != second.filePath)

        #expect(try await storage.load(id: "architecture", type: .project, scope: .project, projectPath: "/tmp/a b")?.content == "content-A")
        #expect(try await storage.load(id: "architecture", type: .project, scope: .project, projectPath: "/tmp/a-b")?.content == "content-B")

        let listedA = await storage.list(scope: .project, projectPath: "/tmp/a b")
        let listedB = await storage.list(scope: .project, projectPath: "/tmp/a-b")
        #expect(listedA.count == 1)
        #expect(listedA.first?.content == "content-A")
        #expect(listedB.count == 1)
        #expect(listedB.first?.content == "content-B")

        try await storage.delete(id: "architecture", scope: .project, projectPath: "/tmp/a b")
        #expect(try await storage.load(id: "architecture", type: .project, scope: .project, projectPath: "/tmp/a b") == nil)
        #expect(try await storage.load(id: "architecture", type: .project, scope: .project, projectPath: "/tmp/a-b")?.content == "content-B")
    }

    @Test("project 路径中的字面量百分号不与编码结果碰撞")
    func projectPathPercentLiteralDoesNotCollide() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        // "/tmp/a b" 编码为 "/tmp/a%20b"；若项目路径本身就是字面量
        // "/tmp/a%20b"，二者必须落在不同目录（% 自身也要编码为 %25）。
        let first = try await storage.save(
            id: "architecture", type: .project, name: "A", description: "",
            content: "content-A", scope: .project, projectPath: "/tmp/a b"
        )
        let second = try await storage.save(
            id: "architecture", type: .project, name: "B", description: "",
            content: "content-B", scope: .project, projectPath: "/tmp/a%20b"
        )

        #expect(first.filePath != second.filePath)
        #expect(try await storage.load(id: "architecture", type: .project, scope: .project, projectPath: "/tmp/a b")?.content == "content-A")
        #expect(try await storage.load(id: "architecture", type: .project, scope: .project, projectPath: "/tmp/a%20b")?.content == "content-B")
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
