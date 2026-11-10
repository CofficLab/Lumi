import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #1115：候选合并必须按 chunk 唯一标识去重，不能用「路径 + 内容前 80 字符」，
/// 否则同前缀的不同 chunk 会互相覆盖，完整命中的旧 chunk 会被较新的部分匹配挤掉。
@Suite struct RAGSQLiteCandidateDedupTests {

    private func makeStore() throws -> (RAGSQLiteStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-rag-dedup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try RAGSQLiteStore(dbURL: root.appendingPathComponent("rag.sqlite"))
        try store.migrate()
        store.runtimeInfo = RAGRuntimeInfo(vectorBackend: .swiftCosine, note: "test")
        return (store, root)
    }

    private func replace(
        _ store: RAGSQLiteStore,
        projectPath: String,
        filePath: String,
        chunks: [RAGChunk]
    ) throws {
        try store.replaceFileChunks(
            projectPath: projectPath,
            filePath: filePath,
            modifiedTime: 1_700_000_000,
            contentHash: "hash-\(filePath)",
            chunks: chunks,
            embeddings: chunks.map { _ in [Float](repeating: 0.5, count: 8) },
            embeddingDimension: 8
        )
    }

    @Test func mergeKeepsChunksThatShareContentPrefix() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectPath = "/tmp/lumi-rag-dedup-project"
        let prefix = String(repeating: "x", count: 80)

        try replace(
            store,
            projectPath: projectPath,
            filePath: "Sources/Shared.swift",
            chunks: [
                RAGChunk(index: 0, content: prefix + " alpha beta"),
                RAGChunk(index: 1, content: prefix + " alpha"),
            ]
        )

        let candidates = try store.loadCandidateChunks(
            projectPath: projectPath,
            queryTerms: ["alpha", "beta"]
        )
        #expect(candidates.count == 2)
        #expect(Set(candidates.map(\.content)) == Set([
            prefix + " alpha beta",
            prefix + " alpha",
        ]))
    }

    @Test func partialMatchDoesNotEvictFullMatch() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectPath = "/tmp/lumi-rag-dedup-project"
        let prefix = String(repeating: "y", count: 80)
        let oldContent = prefix + " alpha beta"
        let newContent = prefix + " alpha"

        try replace(
            store,
            projectPath: projectPath,
            filePath: "Sources/Shared.swift",
            chunks: [
                RAGChunk(index: 0, content: oldContent),
                RAGChunk(index: 1, content: newContent),
            ]
        )

        let stored = try store.loadChunks(projectPath: projectPath)
        let oldID = try #require(stored.first { $0.content == oldContent }?.id)
        let newID = try #require(stored.first { $0.content == newContent }?.id)
        #expect(newID > oldID)

        let candidates = try store.loadCandidateChunks(
            projectPath: projectPath,
            queryTerms: ["alpha", "beta"]
        )
        let ids = Set(candidates.map(\.id))
        #expect(ids.contains(oldID))
        #expect(ids.contains(newID))
    }

    @Test func fallbackOverlapIsDeduplicated() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectPath = "/tmp/lumi-rag-dedup-project"

        try replace(
            store,
            projectPath: projectPath,
            filePath: "Sources/Only.swift",
            chunks: [RAGChunk(index: 0, content: "alpha appears once")]
        )

        let candidates = try store.loadCandidateChunks(
            projectPath: projectPath,
            queryTerms: ["alpha"]
        )
        #expect(candidates.count == 1)
        #expect(candidates.first?.content == "alpha appears once")
    }
}
