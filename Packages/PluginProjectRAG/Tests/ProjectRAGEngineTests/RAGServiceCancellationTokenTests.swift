import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #1117：idle scheduler 的索引切片不在 `backgroundIndexTasks` 里，
/// 前台中断无法直接取消它。切片必须在派发前捕获取消令牌，中断后迟到的
/// 切片不能重新打开后台索引。
@Suite struct RAGServiceCancellationTokenTests {

    private func makeProject(named name: String) throws -> (URL, String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-token-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "func \(name)Feature() {}\n".write(
            to: root.appendingPathComponent("Feature.swift"),
            atomically: true,
            encoding: .utf8
        )
        return (root, RAGPathUtils.normalizeProjectPath(root.path))
    }

    private func makeService() -> (RAGService, URL) {
        let databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-token-db-\(UUID().uuidString)", isDirectory: true)
        return (RAGService(databaseDirectoryProvider: { databaseDirectory }), databaseDirectory)
    }

    @Test("中断前捕获的令牌无法重新打开后台索引", .timeLimit(.minutes(2)))
    func staleTokenCannotRestartBackgroundIndexing() async throws {
        let (projectURL, projectPath) = try makeProject(named: "stale")
        let (service, databaseDirectory) = makeService()
        defer {
            try? FileManager.default.removeItem(at: projectURL)
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        try await service.initialize()

        let stale = await service.backgroundIndexingToken()
        await service.cancelBackgroundIndexing()

        await #expect(throws: CancellationError.self) {
            try await service.ensureIndexed(projectPath: projectPath, background: true, token: stale)
        }
        let statusAfterStale = try await service.getIndexStatus(projectPath: projectPath)
        #expect(statusAfterStale == nil)
        #expect(!RAGService.isIndexing(projectPath: projectPath))

        // 同一个陈旧令牌再次到达仍然失败：迟到切片不得重新打开中断。
        await #expect(throws: CancellationError.self) {
            try await service.ensureIndexed(projectPath: projectPath, background: true, token: stale)
        }

        // 中断之后重新申请的令牌属于新代次，可以正常完成索引。
        let fresh = await service.backgroundIndexingToken()
        #expect(fresh != stale)
        let outcome = try await service.ensureIndexed(
            projectPath: projectPath,
            background: true,
            token: fresh
        )
        #expect(outcome == .indexed)
        let status = try await service.getIndexStatus(projectPath: projectPath)
        #expect((status?.chunkCount ?? 0) > 0)
    }

    @Test("前台索引不受后台取消令牌影响", .timeLimit(.minutes(1)))
    func foregroundIndexingIgnoresBackgroundCancellation() async throws {
        let (projectURL, projectPath) = try makeProject(named: "foreground")
        let (service, databaseDirectory) = makeService()
        defer {
            try? FileManager.default.removeItem(at: projectURL)
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        try await service.initialize()
        await service.cancelBackgroundIndexing()

        let outcome = try await service.ensureIndexed(projectPath: projectPath, background: false)
        #expect(outcome == .indexed)
        let status = try await service.getIndexStatus(projectPath: projectPath)
        #expect((status?.chunkCount ?? 0) > 0)
    }
}
