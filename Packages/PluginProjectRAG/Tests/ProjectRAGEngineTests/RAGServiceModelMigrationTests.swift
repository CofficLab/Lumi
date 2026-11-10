import Foundation
import Testing
@testable import ProjectRAGEngine

/// Regression coverage for issue #924: an existing index built with another
/// embedding model must be rebuilt even when the migration is requested in the
/// background, because every production entry point indexes in the background.
@Suite struct RAGServiceModelMigrationTests {

    @Test("模型不匹配时后台索引仍完成全量重建", .timeLimit(.minutes(1)))
    func backgroundIndexRebuildsWhenEmbeddingModelChanged() async throws {
        let provider = RAGEmbeddingFactory.makeProvider()
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-migration-project-\(UUID().uuidString)", isDirectory: true)
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-migration-db-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: projectURL)
            try? FileManager.default.removeItem(at: databaseDirectory)
        }

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "func migratedFeature() {}\n".write(
            to: projectURL.appendingPathComponent("Feature.swift"),
            atomically: true,
            encoding: .utf8
        )

        let projectPath = RAGPathUtils.normalizeProjectPath(projectURL.path)

        // Seed an index state from an older model whose dimension matches the
        // current one, so only the model identifier differs.
        do {
            let seededStore = try RAGSQLiteStore(dbURL: databaseDirectory.appendingPathComponent("rag.sqlite"))
            try seededStore.migrate()
            try seededStore.upsertProjectIndexState(
                projectPath: projectPath,
                fileCount: 0,
                chunkCount: 0,
                embeddingModel: "legacy-embedding-v1",
                embeddingDimension: provider.dimension
            )
        }

        let service = RAGService(databaseDirectoryProvider: { databaseDirectory })
        try await service.initialize()

        try await service.ensureIndexed(projectPath: projectPath, background: true)

        let status = try await service.getIndexStatus(projectPath: projectPath)
        #expect(status?.embeddingModel == provider.modelIdentifierWithVersion)
        #expect((status?.chunkCount ?? 0) > 0)
    }
}
