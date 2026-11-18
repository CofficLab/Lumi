import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #342：增量索引过去仅凭 mtime 判断「未变化」，内容替换但保留时间戳
/// 的文件永远不会被重索引。修复后一律读内容比对哈希，哈希相同才跳过。
@Suite("RAGIndexer 内容替换与 mtime 保留", .serialized)
struct RAGIndexerContentChangeTests {

    @Test("内容替换但保留 mtime 时必须重建索引", .timeLimit(.minutes(2)))
    func replacedContentWithPreservedMTimeIsReindexed() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-mtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let file = project.appendingPathComponent("Feature.swift")
        try "func alphaFeature() { let alphaToken = 1 }\n".write(
            to: file, atomically: true, encoding: .utf8
        )
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-mtime-db-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: project)
            try? FileManager.default.removeItem(at: databaseDirectory)
        }

        let normalized = RAGPathUtils.normalizeProjectPath(project.path)
        let embedding = RAGEmbeddingFactory.makeProvider()
        let store = try RAGSQLiteStore(dbURL: databaseDirectory.appendingPathComponent("rag.sqlite"))
        try store.migrate()
        try store.configureVectorBackend(
            embeddingDimension: embedding.dimension,
            embeddingModel: embedding.modelIdentifierWithVersion
        )
        let indexer = RAGIndexer(store: store, embeddingProvider: embedding)

        let first = try await indexer.indexProjectIncrementally(at: normalized)
        #expect(first.indexedFiles == 1)
        // 索引键是规范化后的路径（/var → /private/var），按文件名后缀匹配。
        let oldHash = try store.fetchIndexedFileStates(projectPath: normalized).values
            .first { $0.filePath.hasSuffix("Feature.swift") }?.contentHash
        #expect(oldHash != nil)

        // 重写内容并把 mtime 恢复为写入前的值：mtime 判断会漏掉这次替换。
        let originalMTime = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as! Date
        try "func betaFeature() { let betaToken = 2 }\n".write(
            to: file, atomically: true, encoding: .utf8
        )
        try FileManager.default.setAttributes([.modificationDate: originalMTime], ofItemAtPath: file.path)

        let second = try await indexer.indexProjectIncrementally(at: normalized)
        #expect(second.indexedFiles == 1, "内容已替换（mtime 被保留）必须重新索引")

        let newHash = try store.fetchIndexedFileStates(projectPath: normalized).values
            .first { $0.filePath.hasSuffix("Feature.swift") }?.contentHash
        #expect(newHash != nil && newHash != oldHash, "文件状态哈希必须更新为新内容")
    }
}
