import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #1116：`ensureIndexed` 必须把「完成索引」「索引已新鲜」「节流跳过」「已暂停」
/// 区分开，idle scheduler 不能把节流跳过当成成功并清除失败退避。
@Suite struct RAGServiceEnsureOutcomeTests {

    private func makeProject(named name: String) throws -> (URL, String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-outcome-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "func \(name)Feature() {}\n".write(
            to: root.appendingPathComponent("Feature.swift"),
            atomically: true,
            encoding: .utf8
        )
        return (root, RAGPathUtils.normalizeProjectPath(root.path))
    }

    @Test("暂停、新鲜、节流与完成索引返回不同结果", .timeLimit(.minutes(2)))
    func ensureIndexedReportsDistinctOutcomes() async throws {
        let provider = RAGEmbeddingFactory.makeProvider()
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-outcome-db-\(UUID().uuidString)", isDirectory: true)
        let (freshProject, freshPath) = try makeProject(named: "fresh")
        let (missingProject, missingPath) = try makeProject(named: "missing")
        defer {
            try? FileManager.default.removeItem(at: freshProject)
            try? FileManager.default.removeItem(at: missingProject)
            try? FileManager.default.removeItem(at: databaseDirectory)
        }

        // 预置一份当前模型、刚刚索引过的状态，第一次调用应判定为新鲜。
        do {
            let seededStore = try RAGSQLiteStore(dbURL: databaseDirectory.appendingPathComponent("rag.sqlite"))
            try seededStore.migrate()
            try seededStore.upsertProjectIndexState(
                projectPath: freshPath,
                fileCount: 1,
                chunkCount: 1,
                embeddingModel: provider.modelIdentifierWithVersion,
                embeddingDimension: provider.dimension
            )
        }

        let service = RAGService(databaseDirectoryProvider: { databaseDirectory })
        try await service.initialize()

        await service.setIndexingPaused(true)
        let paused = try await service.ensureIndexed(projectPath: freshPath, background: true)
        #expect(paused == .paused)
        await service.setIndexingPaused(false)

        let fresh = try await service.ensureIndexed(projectPath: freshPath, background: true)
        #expect(fresh == .fresh)

        let throttled = try await service.ensureIndexed(projectPath: freshPath, background: true)
        #expect(throttled == .throttled)

        let indexed = try await service.ensureIndexed(projectPath: missingPath, background: true)
        #expect(indexed == .indexed)
    }

    @Test func onlyIndexedAndFreshConfirmProgress() {
        #expect(RAGIndexEnsureOutcome.indexed.confirmsProgress)
        #expect(RAGIndexEnsureOutcome.fresh.confirmsProgress)
        #expect(!RAGIndexEnsureOutcome.throttled.confirmsProgress)
        #expect(!RAGIndexEnsureOutcome.paused.confirmsProgress)
    }
}
