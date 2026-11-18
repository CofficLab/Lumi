import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #602：历史库里的旧维度 embedding 在 configureVectorBackend 重建
/// float[N] 新表时被逐条回灌，维度不匹配让初始化直接失败，且每次启动
/// 重复；ensureIndexed 的 modelMismatch 全量重建因此永远无法执行。修复后
/// 回灌跳过与目标维度不兼容的 blob（chunk 行保留），启动后由模型迁移
/// 全量重建回灌新向量。
@Suite("RAGSQLiteStore 旧维度向量迁移", .serialized)
struct RAGLegacyDimensionMigrationTests {

    @Test("旧维度数据不再让 configureVectorBackend 失败，且可经全量重建恢复", .timeLimit(.minutes(2)))
    func legacyDimensionDataSurvivesBackendReconfiguration() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-legacy-dim-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let file = project.appendingPathComponent("Legacy.swift")
        let legacyContent = "func legacySymbol() { let legacyToken = 2 }\n"
        try legacyContent.write(to: file, atomically: true, encoding: .utf8)
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-legacy-dim-db-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: project)
            try? FileManager.default.removeItem(at: databaseDirectory)
        }

        let normalized = RAGPathUtils.normalizeProjectPath(project.path)
        let dbURL = databaseDirectory.appendingPathComponent("rag.sqlite")

        // 1. 用旧维度（256）造一个历史索引库。
        let legacyStore = try RAGSQLiteStore(dbURL: dbURL)
        try legacyStore.migrate()
        try legacyStore.configureVectorBackend(embeddingDimension: 256, embeddingModel: "legacy-embedder@v1")
        try legacyStore.replaceFileChunks(
            projectPath: normalized,
            filePath: file.path,
            modifiedTime: Date().timeIntervalSince1970,
            contentHash: "legacy-hash",
            chunks: [RAGChunk(index: 0, content: legacyContent)],
            embeddings: [[Float](repeating: 0.25, count: 256)],
            embeddingDimension: 256
        )
        #expect(try legacyStore.vectorIndexRowCount() == 1)

        // 2. 模拟升级后的启动：当前 provider 维度与历史数据不同。
        let current = RAGEmbeddingFactory.makeProvider()
        #expect(current.dimension != 256)
        let upgradedStore = try RAGSQLiteStore(dbURL: dbURL)
        try upgradedStore.migrate()
        // 修复前这里抛「Dimension mismatch for inserted vector」，且每次启动重复。
        try upgradedStore.configureVectorBackend(
            embeddingDimension: current.dimension,
            embeddingModel: current.modelIdentifierWithVersion
        )
        #expect(try upgradedStore.vectorIndexRowCount() == 0, "与目标维度不兼容的旧向量必须被跳过")
        #expect(try upgradedStore.countProjectChunks(projectPath: normalized) == 1, "chunk 行保留，等待模型迁移重建")

        // 3. modelMismatch 触发的全量重建把索引恢复到当前维度。
        let indexer = RAGIndexer(store: upgradedStore, embeddingProvider: current)
        _ = try await indexer.rebuildProjectIndex(at: normalized)
        let chunkCount = try upgradedStore.countProjectChunks(projectPath: normalized)
        #expect(chunkCount > 0)
        #expect(try upgradedStore.vectorIndexRowCount() == chunkCount, "重建后向量表必须与 chunks 行数一致")
    }
}
