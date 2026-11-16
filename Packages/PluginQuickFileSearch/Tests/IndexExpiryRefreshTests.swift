import Testing
import Foundation
import ProviderEditor
@testable import QuickFileSearchPlugin

private struct IndexingTimeout: Error {}

/// 回归 #376：关闭再打开 Cmd+P 面板必须补查当前项目的索引 TTL，过期则重建。
///
/// 每个用例使用独立的 `FileSearchService` 实例，避免共享单例的全局状态在并行
/// 测试间相互污染；索引构建是 detached 异步任务，先轮询等待其完成再注入过期索引。
@MainActor
@Suite("索引过期重建（回归 #376）", .serialized)
struct IndexExpiryRefreshTests {

    @Test("重开面板时过期索引被重建")
    func openingPanelRebuildsExpiredIndex() async throws {
        let service = FileSearchService()
        let root = try Self.makeProject()
        defer { try? FileManager.default.removeItem(at: root) }

        service.updateProject(path: root.path)
        try await Self.waitUntilIndexed(service, path: root.path)

        // 注入一个 5 分钟前的过期索引（同一项目），模拟长时间未重建。
        service.indexStore = FileIndexStore(
            projectPath: root.path,
            files: [],
            lastUpdated: Date().addingTimeInterval(-301)
        )
        #expect(!service.isLoading)

        // 面板 onAppear 调用的生产入口。
        service.refreshIndexIfExpired()

        #expect(service.isLoading, "过期索引应在重开面板时触发重建")
    }

    @Test("重开面板时新鲜索引不重建")
    func openingPanelKeepsFreshIndex() async throws {
        let service = FileSearchService()
        let root = try Self.makeProject()
        defer { try? FileManager.default.removeItem(at: root) }

        service.updateProject(path: root.path)
        try await Self.waitUntilIndexed(service, path: root.path)

        let updated = try #require(service.indexStore.lastUpdated)
        #expect(!service.isLoading)

        service.refreshIndexIfExpired()

        #expect(!service.isLoading, "新鲜索引不应触发重建")
        #expect(service.indexStore.lastUpdated == updated, "新鲜索引不应被替换")
    }

    @Test("无当前项目时重开面板不触发索引")
    func openingPanelWithoutProjectDoesNothing() {
        let service = FileSearchService()

        service.refreshIndexIfExpired()

        #expect(!service.isLoading)
        #expect(service.currentProjectPath.isEmpty)
    }

    // MARK: - Helpers

    private static func makeProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("QFS376-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "x".write(to: root.appendingPathComponent("App.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private static func waitUntilIndexed(_ service: FileSearchService, path: String) async throws {
        for _ in 0..<4000 {
            if !service.isLoading,
               service.indexStore.projectPath == path,
               service.indexStore.lastUpdated != nil {
                return
            }
            await Task.yield()
        }
        throw IndexingTimeout()
    }
}