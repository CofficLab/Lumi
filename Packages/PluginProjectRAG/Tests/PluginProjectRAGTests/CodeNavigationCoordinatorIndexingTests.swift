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