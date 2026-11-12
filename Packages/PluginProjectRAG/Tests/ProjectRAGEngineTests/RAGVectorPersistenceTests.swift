import CSQLite
import Foundation
import Testing

@testable import ProjectRAGEngine

/// Task 3.1：vec0 表跨启动持久化。维度/模型一致且行数完整时不 DROP、不回灌；
/// 维度变化或行数不一致才重建。用独立连接模拟崩溃/漂移现场。
@Suite struct RAGVectorPersistenceTests {
    private func makeStore() throws -> (RAGSQLiteStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-vec-persist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("rag.sqlite")
        let store = try RAGSQLiteStore(dbURL: url)
        try store.migrate()
        return (store, url)
    }

    private func seedChunk(_ store: RAGSQLiteStore, dimension: Int) throws {
        try store.replaceFileChunks(
            projectPath: "/tmp/project",
            filePath: "A.swift",
            modifiedTime: 1,
            contentHash: "hash",
            chunks: [RAGChunk(index: 0, content: "let a = 1")],
            embeddings: [[Float](repeating: 0.1, count: dimension)],
            embeddingDimension: dimension
        )
    }

    /// 独立连接执行 SQL；loadVec 时加载 vec0 扩展（触碰 rag_vec_chunks 必需）。
    private func rawExec(_ url: URL, _ sql: String, loadVec: Bool = false) throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        if loadVec {
            let vecURL = try #require(Bundle.module.url(forResource: "vec0", withExtension: "dylib"))
            #expect(sqlite3_enable_load_extension(db, 1) == SQLITE_OK)
            let path = vecURL.path.replacingOccurrences(of: ".dylib", with: "")
            var error: UnsafeMutablePointer<Int8>?
            let code = sqlite3_load_extension(db, path, nil, &error)
            if let error { sqlite3_free(error) }
            #expect(code == SQLITE_OK)
        }
        var message: UnsafeMutablePointer<Int8>?
        let code = sqlite3_exec(db, sql, nil, nil, &message)
        if let message { sqlite3_free(message) }
        #expect(code == SQLITE_OK)
    }

    private func rawQueryInt(_ url: URL, _ sql: String) throws -> Int? {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(statement, 0))
    }

    @Test("二次初始化保留 vec 行，不 DROP 不回灌")
    func secondInitializeKeepsVectorRows() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try store.configureVectorBackend(embeddingDimension: 64)
        try seedChunk(store, dimension: 64)

        // 把 chunks 里的 embedding 改成 32 维：若发生全量回灌，vec0 会因
        // 维度不匹配拒绝写入而抛错。保留路径不回灌，二次 configure 必须成功。
        try rawExec(url, "UPDATE rag_chunks SET embedding = zeroblob(128);")

        try store.configureVectorBackend(embeddingDimension: 64)

        let matches = try store.searchNearestVectors(
            queryEmbedding: [Float](repeating: 0.1, count: 64),
            limit: 1
        )
        #expect(matches?.count == 1)
    }

    @Test("维度变化强制重建 vec 表")
    func dimensionChangeForcesRebuild() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try store.configureVectorBackend(embeddingDimension: 64)
        try seedChunk(store, dimension: 64)

        // 模拟换模型：chunks 已按新维度重新嵌入。
        try rawExec(url, "UPDATE rag_chunks SET embedding = zeroblob(128), dimension = 32;")

        try store.configureVectorBackend(embeddingDimension: 32, embeddingModel: "model-v2")

        let matches = try store.searchNearestVectors(
            queryEmbedding: [Float](repeating: 0, count: 32),
            limit: 1
        )
        #expect(matches?.count == 1)
        let storedDimension = try rawQueryInt(url, "SELECT value FROM rag_meta WHERE key = 'vector_dimension';")
        #expect(storedDimension == 32)
    }

    @Test("vec 行数与 chunks 不一致触发回灌")
    func rowCountMismatchTriggersRebuild() throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try store.configureVectorBackend(embeddingDimension: 64)
        try seedChunk(store, dimension: 64)

        // 模拟上次崩溃在半途：chunks 在、vec 行丢失。
        try rawExec(url, "DELETE FROM rag_vec_chunks;", loadVec: true)

        try store.configureVectorBackend(embeddingDimension: 64)

        let matches = try store.searchNearestVectors(
            queryEmbedding: [Float](repeating: 0.1, count: 64),
            limit: 1
        )
        #expect(matches?.count == 1)
    }
}