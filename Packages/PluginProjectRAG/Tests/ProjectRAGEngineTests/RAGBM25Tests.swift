import Foundation
import Testing

@testable import ProjectRAGEngine

/// Task 2.1b'：内置 SQLite 无 FTS5（见 RAGFTS5AvailabilityProbeTests），
/// 索引词法候选改用 Swift BM25 排序（df 在候选集内统计，k1=1.2 b=0.75），
/// 再与 ANN 候选做 RRF 融合。
@Suite struct RAGBM25Tests {
    @Test("稀有词命中排在高频词之上")
    func bm25RanksRareTermHigher() {
        let documents = [
            "cache cache cache",
            "cache quokka",
            "cache cache",
        ]
        let scores = RAGBM25.scores(queryTerms: ["cache", "quokka"], documents: documents)
        #expect(scores.count == 3)
        #expect(scores[1] > scores[0])
        #expect(scores[1] > scores[2])
    }

    @Test("同词频下短文档得分更高（长度归一化）")
    func bm25PrefersShorterDocumentAtEqualFrequency() {
        let short = "needle alpha"
        let long = "needle " + String(repeating: "filler ", count: 200)
        let scores = RAGBM25.scores(queryTerms: ["needle"], documents: [long, short])
        #expect(scores[1] > scores[0])
        #expect(scores[0] > 0)
    }

    @Test("中文查询逐字分词后仍有 BM25 得分")
    func cjkQueryReturnsResults() {
        let documents = ["用户登录流程校验", "let value = 1"]
        let terms = RAGTextUtils.tokenize("登录")
        #expect(terms == ["登", "录"])
        let scores = RAGBM25.scores(queryTerms: terms, documents: documents)
        #expect(scores[0] > 0)
        #expect(scores[1] == 0)
    }
}

private final class BM25StubStore: RAGStore, @unchecked Sendable {
    var annChunks: [RAGStoredChunk] = []
    var lexicalChunks: [RAGStoredChunk] = []

    func fetchIndexedFileStates(projectPath: String) throws -> [String: RAGIndexedFileState] { [:] }
    func replaceFileChunks(
        projectPath: String, filePath: String, modifiedTime: Double, contentHash: String,
        chunks: [RAGChunk], embeddings: [[Float]], embeddingDimension: Int
    ) throws {}
    func deleteChunks(projectPath: String, filePath: String) throws {}
    func deleteFileState(projectPath: String, filePath: String) throws {}
    func upsertFileStateOnly(
        projectPath: String, filePath: String, modifiedTime: Double, contentHash: String
    ) throws {}
    func upsertProjectIndexState(
        projectPath: String, fileCount: Int, chunkCount: Int,
        embeddingModel: String, embeddingDimension: Int
    ) throws {}
    func loadChunks(projectPath: String?, limit: Int?) throws -> [RAGStoredChunk] { [] }
    func loadCandidateChunks(
        projectPath: String?, queryTerms: [String], lexicalLimit: Int, fallbackLimit: Int
    ) throws -> [RAGStoredChunk] { lexicalChunks }
    func loadChunksByIDs(_ chunkIDs: [Int64], projectPath: String?) throws -> [RAGStoredChunk] {
        annChunks.filter { chunkIDs.contains($0.id) }
    }
    func fetchProjectIndexState(projectPath: String) throws -> RAGProjectIndexState? { nil }
    func countProjectFiles(projectPath: String) throws -> Int { 0 }
    func countProjectChunks(projectPath: String) throws -> Int { 0 }
    func searchNearestVectors(queryEmbedding: [Float], limit: Int) throws -> [RAGVectorMatch]? {
        annChunks.map { RAGVectorMatch(chunkId: $0.id, distance: 0) }
    }
}

@Suite struct RAGRetrieverBM25FusionTests {
    private func chunk(_ id: Int64, file: String, content: String, embedding: [Float]) -> RAGStoredChunk {
        RAGStoredChunk(
            id: id,
            content: content,
            filePath: "/tmp/project/\(file)",
            embedding: embedding,
            lineRange: RAGLineRange(startLine: 1, endLine: 5)
        )
    }

    @Test("ANN 与 BM25 词法候选经 RRF 融合，共识证据排第一")
    func rrfFusesAnnAndLexical() throws {
        let store = BM25StubStore()
        let x = chunk(1, file: "X.swift", content: "quokka resolver", embedding: [1, 0])
        let y = chunk(2, file: "Y.swift", content: "unrelated body", embedding: [0.9, 0.1])
        let z = chunk(3, file: "Z.swift", content: "cache cache quokka quokka quokka", embedding: [0, 1])
        store.annChunks = [x, y]
        store.lexicalChunks = [z, x]

        let retriever = RAGRetriever(store: store)
        let results = try retriever.retrieve(
            queryEmbedding: [1, 0],
            query: "quokka cache",
            projectPath: "/tmp/project",
            topK: 3
        )

        #expect(results.count == 3)
        #expect(results[0].source == "X.swift")
        #expect(results[0].matchKind == .semantic)
        let zResult = try #require(results.first { $0.source == "Z.swift" })
        #expect(zResult.matchKind == .indexedLexical)
    }
}