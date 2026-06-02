import Testing
import Foundation
@testable import MemoryKit

@Suite("MemoryRetrievalService Tests")
struct MemoryRetrievalTests {

    private func createTempStorage() -> (MemoryStorageService, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryKit-Retrieval-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let service = MemoryStorageService(rootURL: tempDir, verbose: false)
        return (service, tempDir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Keyword Matching

    @Test("关键词匹配")
    func keywordMatch() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let config = MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 2)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        // 创建两条记忆
        _ = try await storage.createMemory(
            id: "go-dev", type: .user, name: "Go Developer",
            description: "User is a Go developer with 10 years experience",
            content: "User has deep expertise in Go backend development",
            scope: .global
        )
        _ = try await storage.createMemory(
            id: "react-newbie", type: .user, name: "React Newbie",
            description: "User is new to React",
            content: "User has no prior React experience",
            scope: .global
        )

        // 搜索 "Go developer"
        let results = await retrieval.findRelevant(
            query: "Go developer experience",
            scope: .global,
            storage: storage
        )

        #expect(!results.isEmpty)
        // Go 相关记忆应该排第一（关键词匹配分数更高）
        #expect(results.first?.id == "go-dev")
    }

    @Test("空结果")
    func emptyResult() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let config = MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 5)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        // 搜索不存在的内容
        let results = await retrieval.findRelevant(
            query: "completely_nonexistent_xyzzy_\(UUID().uuidString)",
            scope: .global,
            storage: storage
        )
        #expect(results.isEmpty)
    }

    @Test("停用词过滤")
    func stopWordsFiltered() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let config = MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 2)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        _ = try await storage.createMemory(
            id: "test-memory", type: .user, name: "Test",
            description: "A test memory",
            content: "Some important content",
            scope: .global
        )

        // 使用停用词搜索，应该没有匹配结果
        let results = await retrieval.findRelevant(
            query: "the is a of in",
            scope: .global,
            storage: storage
        )
        #expect(results.isEmpty)
    }

    // MARK: - Type Weights

    @Test("类型权重")
    func typeWeights() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let config = MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 2)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        // 创建不同类型但相同关键词的记忆
        _ = try await storage.createMemory(
            id: "ref-memory", type: .reference, name: "Ref",
            description: "Reference link",
            content: "Link to documentation",
            scope: .global
        )
        _ = try await storage.createMemory(
            id: "fb-memory", type: .feedback, name: "Feedback",
            description: "Feedback note",
            content: "Feedback about documentation",
            scope: .global
        )

        let results = await retrieval.findRelevant(
            query: "documentation",
            scope: .global,
            storage: storage
        )

        #expect(results.count == 2)
        // feedback 类型权重(1.0) 高于 reference(0.3)，应排前面
        #expect(results.first?.id == "fb-memory")
    }

    // MARK: - Time Decay

    @Test("时效衰减")
    func timeDecay() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        // 设置较短半衰期让衰减效果明显
        let config = MemoryRetrievalConfig(halfLifeDays: 1, maxResults: 2)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        let now = Date()
        let freshContent = """
        ---
        name: Fresh
        description: Fresh memory
        type: user
        created: \(ISO8601DateFormatter().string(from: now))
        updated: \(ISO8601DateFormatter().string(from: now))
        ---

        Fresh content
        """
        let freshFile = tempDir.appendingPathComponent("global/fresh.md")
        try freshContent.write(to: freshFile, atomically: true, encoding: .utf8)

        // 创建旧记忆（30 天前）
        let oldDate = now.addingTimeInterval(-30 * 86400)
        let oldContent = """
        ---
        name: Old
        description: Old memory
        type: user
        created: \(ISO8601DateFormatter().string(from: oldDate))
        updated: \(ISO8601DateFormatter().string(from: oldDate))
        ---

        Old content
        """
        let oldFile = tempDir.appendingPathComponent("global/old.md")
        try oldContent.write(to: oldFile, atomically: true, encoding: .utf8)

        // 需要手动触发索引重建（因为直接写文件绕过了 createMemory）
        try await storage.rebuildIndex(scope: .global)

        let results = await retrieval.findRelevant(
            query: "content",
            scope: .global,
            storage: storage
        )

        #expect(results.count == 2)
        // 新记忆应该排前面（时效分数更高）
        #expect(results.first?.id == "fresh")
    }

    // MARK: - Max Results

    @Test("最大结果数限制")
    func maxResultsLimit() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let config = MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 2)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        // 创建 5 条包含相同关键词的记忆
        for i in 0..<5 {
            _ = try await storage.createMemory(
                id: "item-\(i)", type: .user, name: "Item \(i)",
                description: "Description \(i)",
                content: "Shared keyword content \(i)",
                scope: .global
            )
        }

        let results = await retrieval.findRelevant(
            query: "keyword",
            scope: .global,
            storage: storage
        )

        // 最多返回 2 条
        #expect(results.count == 2)

        // 清理
        for i in 0..<5 {
            try await storage.deleteMemory(id: "item-\(i)", scope: .global)
        }
    }

    @Test("非正数最大结果数返回空结果")
    func nonPositiveMaxResultsReturnsEmpty() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        _ = try await storage.createMemory(
            id: "swift-memory", type: .user, name: "Swift Memory",
            description: "Swift development preference",
            content: "User prefers Swift development",
            scope: .global
        )

        let negativeConfigRetrieval = MemoryRetrievalService(
            config: MemoryRetrievalConfig(halfLifeDays: 30, maxResults: -1),
            verbose: false
        )

        let negativeConfigResults = await negativeConfigRetrieval.findRelevant(
            query: "Swift development",
            scope: .global,
            storage: storage
        )
        #expect(negativeConfigResults.isEmpty)

        let retrieval = MemoryRetrievalService(
            config: MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 5),
            verbose: false
        )

        let zeroOverrideResults = await retrieval.findRelevant(
            query: "Swift development",
            scope: .global,
            storage: storage,
            maxResults: 0
        )
        #expect(zeroOverrideResults.isEmpty)

        let negativeOverrideResults = await retrieval.findRelevant(
            query: "Swift development",
            scope: .global,
            storage: storage,
            maxResults: -3
        )
        #expect(negativeOverrideResults.isEmpty)
    }

    // MARK: - Project Scope Retrieval

    @Test("项目级作用域检索")
    func projectScopeRetrieval() async throws {
        let (storage, tempDir) = createTempStorage()
        defer { cleanup(tempDir) }

        let config = MemoryRetrievalConfig(halfLifeDays: 30, maxResults: 2)
        let retrieval = MemoryRetrievalService(config: config, verbose: false)

        let projectPath = "/Users/test/MyProject"
        let scope: MemoryScope = .project(projectPath)

        _ = try await storage.createMemory(
            id: "proj-goal", type: .project, name: "Project Goal",
            description: "Build a CLI tool",
            content: "CLI tool for automation",
            scope: scope
        )

        let results = await retrieval.findRelevant(
            query: "CLI automation",
            scope: scope,
            storage: storage
        )

        #expect(results.count == 1)
        #expect(results.first?.id == "proj-goal")

        try await storage.deleteMemory(id: "proj-goal", scope: scope)
    }
}
