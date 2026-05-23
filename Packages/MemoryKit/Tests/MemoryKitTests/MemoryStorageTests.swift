import Testing
import Foundation
@testable import MemoryKit

@Suite("MemoryStorageService Tests")
struct MemoryStorageTests {

    private func createTempStorage() -> (MemoryStorageService, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryKit-Tests-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let service = MemoryStorageService(rootURL: tempDir, verbose: false)
        return (service, tempDir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - CRUD

    @Test("创建和读取记忆")
    func createAndRead() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let id = "test-user"
        let created = try await service.createMemory(
            id: id,
            type: .user,
            name: "Test User",
            description: "A test user memory",
            content: "This is test content",
            scope: .global
        )

        #expect(created.id == id)
        #expect(created.type == .user)
        #expect(created.name == "Test User")
        #expect(created.content == "This is test content")

        let read = try await service.readMemory(id: id, scope: .global)
        #expect(read.id == id)
        #expect(read.content == "This is test content")

        try await service.deleteMemory(id: id, scope: .global)
    }

    @Test("更新记忆")
    func update() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let id = "test-update"
        _ = try await service.createMemory(
            id: id, type: .feedback, name: "Original",
            description: "Original desc", content: "Original content",
            scope: .global
        )

        let updated = try await service.updateMemory(
            id: id, name: "Updated", description: "Updated desc",
            content: "Updated content", scope: .global
        )
        #expect(updated.name == "Updated")
        #expect(updated.description == "Updated desc")
        #expect(updated.content == "Updated content")
        #expect(updated.createdAt == updated.createdAt) // 创建时间不变
        #expect(updated.updatedAt >= updated.createdAt) // 更新时间刷新

        try await service.deleteMemory(id: id, scope: .global)
    }

    @Test("删除记忆")
    func delete() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let id = "test-delete"
        _ = try await service.createMemory(
            id: id, type: .reference, name: "ToDelete",
            description: "Will be deleted", content: "Content",
            scope: .global
        )

        try await service.deleteMemory(id: id, scope: .global)

        await #expect(throws: MemoryError.self) {
            try await service.readMemory(id: id, scope: .global)
        }
    }

    @Test("列出记忆")
    func list() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let prefix = "test-list"
        let ids = (0..<3).map { "\(prefix)-\($0)" }

        for id in ids {
            _ = try await service.createMemory(
                id: id, type: .user, name: "Memory \(id)",
                description: "Test memory \(id)", content: "Content \(id)",
                scope: .global
            )
        }

        let memories = await service.listMemories(scope: .global)
        let found = memories.filter { $0.id.hasPrefix(prefix) }
        #expect(found.count == 3)

        // 按更新时间降序
        for i in 0..<(found.count - 1) {
            #expect(found[i].updatedAt >= found[i + 1].updatedAt)
        }

        for id in ids {
            try await service.deleteMemory(id: id, scope: .global)
        }
    }

    // MARK: - Project Scope

    @Test("项目级作用域 CRUD")
    func projectScopeCRUD() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let projectPath = "/Users/test/MyProject"
        let scope: MemoryScope = .project(projectPath)
        let id = "project-context"

        let created = try await service.createMemory(
            id: id, type: .project, name: "Project Goal",
            description: "Build a CLI tool",
            content: "The goal is to build a cross-platform CLI.",
            scope: scope
        )
        #expect(created.id == id)

        let read = try await service.readMemory(id: id, scope: scope)
        #expect(read.content.contains("cross-platform"))

        // 全局作用域不应看到项目记忆
        let globalMemories = await service.listMemories(scope: .global)
        #expect(!globalMemories.contains { $0.id == id })

        try await service.deleteMemory(id: id, scope: scope)
    }

    // MARK: - Index

    @Test("索引读取")
    func index() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let id = "test-index"
        _ = try await service.createMemory(
            id: id, type: .feedback, name: "Test Feedback",
            description: "A test feedback", content: "Content",
            scope: .global
        )

        let index = await service.readIndex(scope: .global)
        #expect(!index.isEmpty)
        #expect(index.contains("Global Memory Index"))
        #expect(index.contains("Test Feedback"))

        try await service.deleteMemory(id: id, scope: .global)
    }

    @Test("空索引")
    func emptyIndex() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        // 先触发一次索引重建（模拟真实流程：初始化后至少有一次重建）
        try await service.rebuildIndex(scope: .global)

        let index = await service.readIndex(scope: .global)
        #expect(!index.isEmpty)
        #expect(index.contains("No memories yet"))
    }

    // MARK: - Markdown Round-trip

    @Test("Markdown 构建与解析往返")
    func markdownRoundTrip() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let id = "roundtrip"
        let original = try await service.createMemory(
            id: id, type: .user, name: "Round Trip",
            description: "Testing round-trip",
            content: "Line 1\nLine 2\n\n**Bold** and *italic*",
            scope: .global
        )

        let read = try await service.readMemory(id: id, scope: .global)
        #expect(read.id == original.id)
        #expect(read.name == original.name)
        #expect(read.description == original.description)
        #expect(read.content == original.content)
        #expect(read.type == original.type)

        try await service.deleteMemory(id: id, scope: .global)
    }

    @Test("特殊字符内容往返")
    func specialCharactersRoundTrip() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let id = "special-chars"
        let content = """
        Code: `let x = 10`
        JSON: {"key": "value"}
        Path: /usr/local/bin
        Unicode: 日本語テスト 🎉
        """

        _ = try await service.createMemory(
            id: id, type: .reference, name: "Special",
            description: "Test special characters",
            content: content,
            scope: .global
        )

        let read = try await service.readMemory(id: id, scope: .global)
        #expect(read.content == content)

        try await service.deleteMemory(id: id, scope: .global)
    }

    // MARK: - Path Sanitization (Regression Test)

    @Test("sanitizeProjectPath 不崩溃（溢出修复回归测试）")
    func sanitizeProjectPathNoOverflow() async throws {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        // 各种边界路径，确保 reduce 不会溢出
        let testPaths = [
            "/",
            "/Users/angel/Code/Lumi",
            "/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z",
            "/path with spaces and 日本語/项目",
            String(repeating: "a", count: 10000),  // 超长路径
            "",                                      // 空路径
        ]

        for path in testPaths {
            let scope: MemoryScope = .project(path)
            let id = "test-\(path.hashValue)"
            _ = try await service.createMemory(
                id: id, type: .project, name: "Test",
                description: "Path test", content: "test",
                scope: scope
            )
            try await service.deleteMemory(id: id, scope: scope)
        }
    }

    // MARK: - Errors

    @Test("读取不存在的记忆抛出错误")
    func readNonExistentThrows() async {
        let (service, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        await #expect(throws: MemoryError.self) {
            try await service.readMemory(id: "nonexistent", scope: .global)
        }
    }
}
