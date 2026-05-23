import Testing
import Foundation

/// MemoryPlugin 单元测试
///
/// 测试记忆系统的核心逻辑：模型、存储、检索。
@Suite("Memory Plugin Tests")
struct MemoryPluginTests {

    // MARK: - MemoryType Tests

    @Test("MemoryType 有四种类型")
    func memoryTypeHasFourTypes() {
        #expect(MemoryType.allCases.count == 4)
        #expect(MemoryType(rawValue: "user") == .user)
        #expect(MemoryType(rawValue: "feedback") == .feedback)
        #expect(MemoryType(rawValue: "project") == .project)
        #expect(MemoryType(rawValue: "reference") == .reference)
        #expect(MemoryType(rawValue: "invalid") == nil)
    }

    @Test("MemoryType 默认作用域")
    func memoryTypeDefaultScope() {
        #expect(MemoryType.user.defaultScope == .global)
        #expect(MemoryType.feedback.defaultScope == .global)
    }

    // MARK: - MemoryScope Tests

    @Test("MemoryScope 相等性")
    func memoryScopeEquality() {
        #expect(MemoryScope.global == MemoryScope.global)
        #expect(MemoryScope.project("/foo") == MemoryScope.project("/foo"))
        #expect(MemoryScope.project("/foo") != MemoryScope.project("/bar"))
        #expect(MemoryScope.global != MemoryScope.project("/foo"))
    }

    // MARK: - MemoryItem Tests

    @Test("MemoryItem 时效计算")
    func memoryItemAgeCalculation() {
        let now = Date()
        let fresh = MemoryItem(
            id: "fresh", filename: "fresh.md", type: .user,
            name: "Fresh", description: "Fresh memory",
            content: "Content", createdAt: now, updatedAt: now,
            filePath: "/tmp/fresh.md"
        )
        #expect(fresh.ageInDays == 0)
        #expect(!fresh.isStale)

        let old = MemoryItem(
            id: "old", filename: "old.md", type: .user,
            name: "Old", description: "Old memory",
            content: "Content",
            createdAt: now, updatedAt: now.addingTimeInterval(-8 * 86400),
            filePath: "/tmp/old.md"
        )
        #expect(old.ageInDays == 8)
        #expect(old.isStale)
    }

    @Test("MemoryItem 格式化摘要")
    func memoryItemFormattedSummary() {
        let item = MemoryItem(
            id: "test", filename: "test.md", type: .feedback,
            name: "No Summary", description: "Don't summarize",
            content: "Content", createdAt: Date(), updatedAt: Date(),
            filePath: "/tmp/test.md"
        )
        #expect(item.formattedSummary() == "[feedback] No Summary — Don't summarize")
    }

    @Test("MemoryItem 格式化内容含时效提醒")
    func memoryItemFormattedContentWithStaleWarning() {
        let now = Date()
        let stale = MemoryItem(
            id: "stale", filename: "stale.md", type: .project,
            name: "Old Decision", description: "Made long ago",
            content: "Use database X",
            createdAt: now, updatedAt: now.addingTimeInterval(-30 * 86400),
            filePath: "/tmp/stale.md"
        )
        let content = stale.formattedContent()
        #expect(content.contains("⚠️"))
        #expect(content.contains("30 天前"))
    }

    // MARK: - MemoryStorageService Tests

    @Test("MemoryStorageService 创建和读取记忆")
    func memoryStorageCreateAndRead() async throws {
        let service = MemoryStorageService.shared
        let id = "test-\(UUID().uuidString.prefix(8))"

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

        let read = try await service.readMemory(id: id, scope: .global)
        #expect(read.id == id)
        #expect(read.content == "This is test content")

        // 清理
        try await service.deleteMemory(id: id, scope: .global)
    }

    @Test("MemoryStorageService 更新记忆")
    func memoryStorageUpdate() async throws {
        let service = MemoryStorageService.shared
        let id = "test-update-\(UUID().uuidString.prefix(8))"

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
        #expect(updated.content == "Updated content")

        // 清理
        try await service.deleteMemory(id: id, scope: .global)
    }

    @Test("MemoryStorageService 删除记忆")
    func memoryStorageDelete() async throws {
        let service = MemoryStorageService.shared
        let id = "test-delete-\(UUID().uuidString.prefix(8))"

        _ = try await service.createMemory(
            id: id, type: .reference, name: "ToDelete",
            description: "Will be deleted", content: "Content",
            scope: .global
        )

        try await service.deleteMemory(id: id, scope: .global)

        do {
            _ = try await service.readMemory(id: id, scope: .global)
            Issue.record("Should have thrown error for deleted memory")
        } catch {
            // Expected
        }
    }

    @Test("MemoryStorageService 列出记忆")
    func memoryStorageList() async throws {
        let service = MemoryStorageService.shared
        let prefix = "test-list-\(UUID().uuidString.prefix(8))"

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

        // 清理
        for id in ids {
            try await service.deleteMemory(id: id, scope: .global)
        }
    }

    @Test("MemoryStorageService 索引读取")
    func memoryStorageIndex() async throws {
        let service = MemoryStorageService.shared
        let id = "test-index-\(UUID().uuidString.prefix(8))"

        _ = try await service.createMemory(
            id: id, type: .feedback, name: "Test Feedback",
            description: "A test feedback", content: "Content",
            scope: .global
        )

        let index = await service.readIndex(scope: .global)
        #expect(!index.isEmpty)

        // 清理
        try await service.deleteMemory(id: id, scope: .global)
    }

    // MARK: - MemoryRetrievalService Tests

    @Test("MemoryRetrievalService 关键词匹配")
    func memoryRetrievalKeywordMatch() async throws {
        let storage = MemoryStorageService.shared
        let retrieval = MemoryRetrievalService.shared
        let prefix = "test-retrieve-\(UUID().uuidString.prefix(8))"

        // 创建几条记忆
        _ = try await storage.createMemory(
            id: "\(prefix)-go", type: .user, name: "Go Developer",
            description: "User is a Go developer with 10 years experience",
            content: "User has deep expertise in Go backend development",
            scope: .global
        )
        _ = try await storage.createMemory(
            id: "\(prefix)-react", type: .user, name: "React Newbie",
            description: "User is new to React",
            content: "User has no prior React experience",
            scope: .global
        )

        // 搜索 "Go developer"
        let results = await retrieval.findRelevant(
            query: "Go developer experience",
            scope: .global,
            maxResults: 2
        )

        // Go 相关记忆应该排第一
        #expect(!results.isEmpty)
        #expect(results.first?.id == "\(prefix)-go")

        // 清理
        try await storage.deleteMemory(id: "\(prefix)-go", scope: .global)
        try await storage.deleteMemory(id: "\(prefix)-react", scope: .global)
    }

    @Test("MemoryRetrievalService 空结果")
    func memoryRetrievalEmptyResult() async {
        let retrieval = MemoryRetrievalService.shared

        // 搜索不存在的内容
        let results = await retrieval.findRelevant(
            query: "completely_nonexistent_xyzzy_\(UUID().uuidString)",
            scope: .global,
            maxResults: 5
        )
        #expect(results.isEmpty)
    }

    // MARK: - MemoryPluginLocalStore Tests

    @Test("LocalStore 读写布尔值")
    func localStoreBoolRoundTrip() {
        let store = MemoryPluginLocalStore.shared
        let key = MemoryPluginLocalStore.Key.verboseLogging

        let original = store.bool(forKey: key)
        store.set(!original, forKey: key)
        #expect(store.bool(forKey: key) == !original)

        // 恢复
        store.set(original, forKey: key)
    }

    @Test("LocalStore 读写整数")
    func localStoreIntRoundTrip() {
        let store = MemoryPluginLocalStore.shared
        let key = MemoryPluginLocalStore.Key.maxRelevantMemories

        let original = store.integer(forKey: key)
        store.set(7, forKey: key)
        #expect(store.integer(forKey: key) == 7)

        // 恢复
        store.set(original, forKey: key)
    }

    // MARK: - Markdown 格式 Tests

    @Test("MemoryToolError 描述")
    func memoryToolErrorDescription() {
        let err1 = MemoryToolError.missingArgument("id")
        #expect(err1.errorDescription?.contains("id") == true)

        let err2 = MemoryToolError.invalidArgument("bad type")
        #expect(err2.errorDescription?.contains("bad type") == true)
    }
}
