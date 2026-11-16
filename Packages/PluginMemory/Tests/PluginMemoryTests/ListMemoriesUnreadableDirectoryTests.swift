import Foundation
import Testing
import KitAgentTool

@testable import PluginMemory

/// 回归 #529：`list_memories` 把目录枚举失败（权限/IO，或路径被普通文件占位）
/// 当作空列表，成功返回「暂无保存的记忆」，掩盖真实的文件系统错误。
/// 只有目录确实不存在或成功枚举且为空时才允许空列表；存在但不可枚举必须抛出存储/工具失败。
@Suite("ListMemories 不可枚举目录")
@MainActor
struct ListMemoriesUnreadableDirectoryTests {
    private func makeTempStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-list-unreadable-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    private func makeTool(_ storage: MemoryFileStorage) -> ListMemoriesTool {
        ListMemoriesTool(storage: storage, projectCapability: MemoryProjectCapabilityAdapter(project: nil))
    }

    /// 把 global 目录替换为普通文件，使其不可枚举（ portable，无需权限操作）。
    private func occupyGlobalWithFile(_ root: URL) throws {
        let globalDir = root.appendingPathComponent("global")
        try FileManager.default.removeItem(at: globalDir)
        try Data("blocker".utf8).write(to: globalDir)
    }

    @Test("目录路径被普通文件占位时 list 抛出 storageUnavailable 而非返回空")
    func listThrowsWhenDirectoryPathIsRegularFile() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        try occupyGlobalWithFile(root)

        do {
            let items = try await storage.list(scope: .global, projectPath: nil)
            Issue.record("不可枚举目录必须抛出，而非返回 \(items.count) 条")
        } catch let error as MemoryError {
            guard case .storageUnavailable = error else {
                Issue.record("期望 storageUnavailable，实际 \(error)")
                return
            }
        }
    }

    @Test("list_memories 对不可枚举目录抛出存储失败，而非误报暂无记忆")
    func listToolThrowsWhenDirectoryUnreadable() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        try occupyGlobalWithFile(root)
        let tool = makeTool(storage)

        do {
            let result = try await tool.execute(arguments: ["scope": ToolArgument("global")])
            Issue.record("不可枚举目录必须抛出工具错误，而非返回成功文案：\(result)")
        } catch let error as ToolExecutionError {
            let desc = error.errorDescription ?? ""
            #expect(desc.contains("storage unavailable"), "应报告存储不可读：\(desc)")
            #expect(!desc.contains("暂无"), "不得伪装成暂无记忆：\(desc)")
        }
    }

    @Test("目录成功枚举且为空时仍返回空列表与暂无记忆文案")
    func emptyDirectoryStillReportsNoMemories() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let items = try await storage.list(scope: .global, projectPath: nil)
        #expect(items.isEmpty)

        let tool = makeTool(storage)
        let result = try await tool.execute(arguments: ["scope": ToolArgument("global")])
        #expect(result.contains("暂无保存的记忆"))
    }

    @Test("项目目录确实不存在时返回空列表而非抛出")
    func missingProjectDirectoryReturnsEmpty() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }

        let items = try await storage.list(scope: .project, projectPath: "/tmp/absent-\(UUID().uuidString)")
        #expect(items.isEmpty)
    }

    #if os(macOS)
    @Test("目录存在但无读权限时 list 抛出 storageUnavailable")
    func listThrowsWhenDirectoryHasNoReadPermission() async throws {
        let (storage, root) = makeTempStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await storage.save(
            id: "m", type: .project, name: "N", description: "d",
            content: "v", scope: .global, projectPath: nil
        )
        let globalDir = root.appendingPathComponent("global")
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0)], ofItemAtPath: globalDir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: globalDir.path)
        }

        do {
            let items = try await storage.list(scope: .global, projectPath: nil)
            Issue.record("无读权限目录必须抛出，而非返回 \(items.count) 条")
        } catch let error as MemoryError {
            guard case .storageUnavailable = error else {
                Issue.record("期望 storageUnavailable，实际 \(error)")
                return
            }
        }
    }
    #endif
}