import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归覆盖 issue #1062：扫描失败必须与「项目确实为空」区分开，
/// 否则增量索引会把旧记录当成已删除文件清理掉。
@Suite struct RAGFileScannerFailureTests {

    @Test func missingRootThrows() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-missing-\(UUID().uuidString)", isDirectory: true)
            .path

        #expect(throws: RAGError.self) {
            try RAGFileScanner.discoverFilesOrThrow(in: path)
        }
        // 检索侧沿用宽松接口：失败退化为空结果，不阻断单次检索。
        #expect(RAGFileScanner.discoverFiles(in: path).isEmpty)
    }

    @Test func regularFileRootThrows() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-file-root-\(UUID().uuidString).swift")
        try "func unrelated() {}\n".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: RAGError.self) {
            try RAGFileScanner.discoverFilesOrThrow(in: fileURL.path)
        }
    }

    @Test func emptyDirectoryReturnsNoFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let files = try RAGFileScanner.discoverFilesOrThrow(in: directory.path)
        #expect(files.isEmpty)
    }
}

@Suite struct RAGIndexerScannerFailureTests {

    @Test func incrementalIndexKeepsRecordsWhenRootDisappears() async throws {
        let (indexer, store, root, projectURL) = try makeIndexer()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectPath = RAGPathUtils.normalizeProjectPath(projectURL.path)

        _ = try await indexer.indexProjectIncrementally(at: projectPath)
        let fileCountBefore = try store.countProjectFiles(projectPath: projectPath)
        let stateBefore = try store.fetchProjectIndexState(projectPath: projectPath)
        #expect(fileCountBefore > 0)
        #expect(stateBefore != nil)

        try FileManager.default.removeItem(at: projectURL)

        await #expect(throws: RAGError.self) {
            _ = try await indexer.indexProjectIncrementally(at: projectPath)
        }

        let fileCountAfter = try store.countProjectFiles(projectPath: projectPath)
        let stateAfter = try store.fetchProjectIndexState(projectPath: projectPath)
        #expect(fileCountAfter == fileCountBefore)
        #expect(stateAfter?.chunkCount == stateBefore?.chunkCount)
        #expect(stateAfter?.embeddingModel == stateBefore?.embeddingModel)
    }

    @Test func rebuildKeepsRecordsWhenRootDisappears() async throws {
        let (indexer, store, root, projectURL) = try makeIndexer()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectPath = RAGPathUtils.normalizeProjectPath(projectURL.path)

        _ = try await indexer.rebuildProjectIndex(at: projectPath)
        let fileCountBefore = try store.countProjectFiles(projectPath: projectPath)
        #expect(fileCountBefore > 0)

        try FileManager.default.removeItem(at: projectURL)

        // 重建会先删除旧记录再重新索引；扫描失败必须在删除之前中止。
        await #expect(throws: RAGError.self) {
            _ = try await indexer.rebuildProjectIndex(at: projectPath)
        }

        let fileCountAfter = try store.countProjectFiles(projectPath: projectPath)
        #expect(fileCountAfter == fileCountBefore)
    }

    private func makeIndexer() throws -> (RAGIndexer, RAGSQLiteStore, URL, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-scanner-failure-\(UUID().uuidString)", isDirectory: true)
        let projectURL = root.appendingPathComponent("Project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "func migratedFeature() {}\n".write(
            to: projectURL.appendingPathComponent("Feature.swift"),
            atomically: true,
            encoding: .utf8
        )

        let store = try RAGSQLiteStore(dbURL: root.appendingPathComponent("rag.sqlite"))
        try store.migrate()
        store.runtimeInfo = RAGRuntimeInfo(vectorBackend: .swiftCosine)

        let indexer = RAGIndexer(
            store: store,
            embeddingProvider: MockEmbeddingProvider(dimension: 16)
        )
        return (indexer, store, root, projectURL)
    }
}
