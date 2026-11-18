import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #341：已索引文件被清空（或只剩空白）后，增量索引过去只把它算作
/// skipped，历史 chunks/向量与文件状态都留在库里，检索继续返回已删除的
/// 正文。修复后空文件视为「当前无可索引内容」，清掉其全部索引痕迹。
@Suite("RAGIndexer 空文件清理", .serialized)
struct RAGIndexerEmptyFileTests {

    @Test("清空已索引文件后其 chunks 与文件状态必须被删除", .timeLimit(.minutes(2)))
    func emptiedFilePurgesIndexState() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let file = project.appendingPathComponent("A.swift")
        try "func obsoleteSymbol() {}\n".write(to: file, atomically: true, encoding: .utf8)
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-empty-db-\(UUID().uuidString)", isDirectory: true)
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
        #expect(try store.countProjectChunks(projectPath: normalized) > 0)
        #expect(try store.countProjectFiles(projectPath: normalized) == 1)

        // 清空文件（文件仍存在，因此「删除文件清理」不会处理它）。
        try "".write(to: file, atomically: true, encoding: .utf8)

        let second = try await indexer.indexProjectIncrementally(at: normalized)
        #expect(try store.countProjectChunks(projectPath: normalized) == 0, "空文件的旧 chunks 必须被删除")
        #expect(try store.countProjectFiles(projectPath: normalized) == 0, "空文件的文件状态必须被删除")
        #expect(second.indexedFiles == 0)
    }

    @Test("只剩空白的文件同样清理索引痕迹", .timeLimit(.minutes(2)))
    func whitespaceOnlyFilePurgesIndexState() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-blank-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let file = project.appendingPathComponent("B.swift")
        try "func leftoverSymbol() {}\n".write(to: file, atomically: true, encoding: .utf8)
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-blank-db-\(UUID().uuidString)", isDirectory: true)
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

        try "   \n\t\n".write(to: file, atomically: true, encoding: .utf8)

        _ = try await indexer.indexProjectIncrementally(at: normalized)
        #expect(try store.countProjectChunks(projectPath: normalized) == 0)
        #expect(try store.countProjectFiles(projectPath: normalized) == 0)
    }
}
