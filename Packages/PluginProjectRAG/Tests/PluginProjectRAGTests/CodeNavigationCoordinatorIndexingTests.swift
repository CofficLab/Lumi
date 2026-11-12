import Foundation
@testable import PluginProjectRAG
import ProjectRAGEngine
import ProviderProjectRAG
import Testing

@MainActor
private final class IndexingStubProvider: ProjectRAGProviding {
    var currentProjectPath: String?
    let isInitialized = true
    var indexing: Bool
    var hasIndex: Bool
    var semanticResults: [ProjectRAGSearchResult]
    var searchCallCount = 0
    var ensureIndexedCallCount = 0

    init(indexing: Bool, hasIndex: Bool, semanticResults: [ProjectRAGSearchResult] = []) {
        self.indexing = indexing
        self.hasIndex = hasIndex
        self.semanticResults = semanticResults
    }

    func isIndexing(projectPath: String) -> Bool { indexing }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        searchCallCount += 1
        return ProjectRAGResponse(query: query, results: semanticResults)
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        ensureIndexedCallCount += 1
    }

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        guard hasIndex else { return nil }
        return ProjectRAGIndexStatus(
            projectPath: projectPath,
            lastIndexedAt: Date(),
            fileCount: 1,
            chunkCount: 1,
            isStale: false
        )
    }
}

/// 索引进行中时，实时搜索（词法/路径）必须仍然可用；语义检索不被排队。
@Suite("CodeNavigationCoordinatorIndexing", .serialized)
@MainActor
struct CodeNavigationCoordinatorIndexingTests {

    private func makeProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-coordinator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "let liveNeedle = 42\n".write(
            to: root.appendingPathComponent("Live.swift"), atomically: true, encoding: .utf8
        )
        return root
    }

    @Test("live search works while indexing")
    func liveSearchWorksWhileIndexing() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        let provider = IndexingStubProvider(indexing: true, hasIndex: false)

        let response = try await CodeNavigationCoordinator(provider: provider).search(
            query: "liveNeedle", projectPath: root.path, topK: 5
        )

        #expect(!response.results.isEmpty)
        #expect(response.results.allSatisfy {
            $0.matchKind == .filesystemLexical || $0.matchKind == .filesystemPath
        })
    }

    @Test("semantic search is skipped while indexing")
    func semanticSkippedWhileIndexing() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        let provider = IndexingStubProvider(indexing: true, hasIndex: false)

        _ = try await CodeNavigationCoordinator(provider: provider).search(
            query: "liveNeedle", projectPath: root.path, topK: 5
        )

        #expect(provider.searchCallCount == 0)
        #expect(provider.ensureIndexedCallCount == 0)
    }

    @Test("semantic and live results merge when idle")
    func semanticMergedWhenIdle() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        let semantic = ProjectRAGSearchResult(
            content: "semantic chunk",
            source: "Sources/Semantic.swift",
            score: 0.9,
            matchKind: .semantic,
            lineRange: ProjectRAGLineRange(startLine: 1, endLine: 3)
        )
        let provider = IndexingStubProvider(indexing: false, hasIndex: true, semanticResults: [semantic])

        let response = try await CodeNavigationCoordinator(provider: provider).search(
            query: "liveNeedle", projectPath: root.path, topK: 5
        )

        #expect(provider.searchCallCount == 1)
        #expect(response.results.contains { $0.matchKind == .semantic })
        #expect(response.results.contains { $0.matchKind == .filesystemLexical })
    }
}

/// 词法/路径搜索必须使用提取后的搜索词，疑问词不得进入 rg 模式。
@Suite("CodeNavigationCoordinatorQuery", .serialized)
@MainActor
struct CodeNavigationCoordinatorQueryTests {

    @Test("lexical search uses extracted terms")
    func lexicalSearchUsesExtractedTerms() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-query-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // A.swift 只含疑问词字符，B.swift 含领域词。旧实现按单字 OR 匹配会
        // 让两者同分、按文件名取 A；提取后只有 B 命中。
        try "怎么么么怎\n".write(
            to: root.appendingPathComponent("A.swift"), atomically: true, encoding: .utf8
        )
        try "登录登录\n".write(
            to: root.appendingPathComponent("B.swift"), atomically: true, encoding: .utf8
        )
        let provider = IndexingStubProvider(indexing: true, hasIndex: false)

        let response = try await CodeNavigationCoordinator(provider: provider).search(
            query: "登录功能是怎么设计的", projectPath: root.path, topK: 1
        )

        let first = try #require(response.results.first)
        #expect(first.source == "B.swift")
    }
}