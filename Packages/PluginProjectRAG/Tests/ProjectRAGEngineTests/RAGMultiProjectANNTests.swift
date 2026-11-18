import Foundation
import Testing

@testable import ProjectRAGEngine

/// #343：多项目共用一张 vec0 表时，固定全局 ANN 窗口内其他项目的近邻
/// 会挤占本项目的召回名额。检索必须按需扩窗，直到凑满 topK 个本项目
/// 候选或向量表取尽。
@Suite struct RAGMultiProjectANNTests {
    private let dimension = 64

    private func makeStore() throws -> (RAGSQLiteStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-ann-multi-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("rag.sqlite")
        let store = try RAGSQLiteStore(dbURL: url)
        try store.migrate()
        try store.configureVectorBackend(embeddingDimension: dimension)
        return (store, url)
    }

    /// A 项目 70 个 chunk 全部紧贴查询向量；B 项目 3 个 chunk 距离更远。
    /// 固定窗口 max(topK*12, 60) < 73 行，第一轮全局近邻全是 A。
    private func seedTwoProjects(_ store: RAGSQLiteStore) throws {
        let queryVector = [Float](repeating: 0.1, count: dimension)
        for i in 0..<70 {
            try store.replaceFileChunks(
                projectPath: "/tmp/proj-a",
                filePath: "A\(i).swift",
                modifiedTime: 1,
                contentHash: "hash-a-\(i)",
                chunks: [RAGChunk(index: 0, content: "alpha filler \(i)")],
                embeddings: [queryVector],
                embeddingDimension: dimension
            )
        }
        for i in 0..<3 {
            try store.replaceFileChunks(
                projectPath: "/tmp/proj-b",
                filePath: "B\(i).swift",
                modifiedTime: 1,
                contentHash: "hash-b-\(i)",
                chunks: [RAGChunk(index: 0, content: "needle content \(i)")],
                embeddings: [[Float](repeating: 0.095, count: dimension)],
                embeddingDimension: dimension
            )
        }
    }

    @Test("其他项目占满窗口时按需扩窗，本项目候选凑满 topK")
    func expandsWindowUntilProjectCandidatesReachTopK() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try seedTwoProjects(store)

        let retriever = RAGRetriever(store: store)
        let query = [Float](repeating: 0.1, count: dimension)
        let candidates = try retriever.loadANNCandidates(
            queryEmbedding: query,
            projectPath: "/tmp/proj-b",
            topK: 2
        )

        #expect(candidates.count == 3)
        #expect(candidates.allSatisfy { $0.filePath.hasPrefix("B") })
    }

    @Test("本项目候选不足 topK 时扩到向量表取尽并返回全部")
    func exhaustsTableWhenProjectHasFewerChunksThanTopK() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try seedTwoProjects(store)

        let retriever = RAGRetriever(store: store)
        let query = [Float](repeating: 0.1, count: dimension)
        let candidates = try retriever.loadANNCandidates(
            queryEmbedding: query,
            projectPath: "/tmp/proj-b",
            topK: 5
        )

        #expect(candidates.count == 3)
    }

    @Test("无项目过滤时保持单窗口行为")
    func globalSearchKeepsSingleWindow() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try seedTwoProjects(store)

        let retriever = RAGRetriever(store: store)
        let query = [Float](repeating: 0.1, count: dimension)
        let candidates = try retriever.loadANNCandidates(
            queryEmbedding: query,
            projectPath: nil,
            topK: 2
        )

        #expect(candidates.count == max(2 * 12, 60))
    }

    @Test("retrieve 端到端：B 项目结果来自 ANN 语义列表而非词法兜底")
    func retrieveReturnsSemanticResultsForDistantProject() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try seedTwoProjects(store)

        let retriever = RAGRetriever(store: store)
        let query = [Float](repeating: 0.1, count: dimension)
        let results = try retriever.retrieve(
            queryEmbedding: query,
            query: "needle",
            projectPath: "/tmp/proj-b",
            topK: 2
        )

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.content.hasPrefix("needle") })
        #expect(results.contains { $0.matchKind == .semantic })
    }
}
