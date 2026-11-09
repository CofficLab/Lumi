import Foundation
import KernelCore
import ProviderProjectRAG
import Testing
@testable import PluginProjects

/// Regression coverage for issue #1065: every settings re-render used to
/// register a new RAG status observer without cancelling the previous one.
@Suite("ProjectsPlugin RAG 状态观察者")
@MainActor
struct ProjectRAGStatusObserverReplacementTests {
    @Test("重复构建详情区块会注销旧观察者")
    func repeatedSectionCreationReplacesObserver() throws {
        let kernel = KernelCoreContainer()
        let spy = SpyRAGProvider()
        try kernel.registerProvider((any ProjectRAGProviding).self, spy)
        let plugin = ProjectsPlugin()

        _ = plugin.makeRAGStatusSection(projectPath: "/tmp/project-a", kernel: kernel)
        _ = plugin.makeRAGStatusSection(projectPath: "/tmp/project-a", kernel: kernel)

        #expect(spy.addedCount == 2)
        #expect(spy.cancelledCount == 1, "同一路径重建区块时旧观察者没有注销")
        #expect(spy.liveCount == 1)
    }

    @Test("切换到另一个项目会注销不可见详情的观察者")
    func switchingProjectCancelsInvisibleObserver() throws {
        let kernel = KernelCoreContainer()
        let spy = SpyRAGProvider()
        try kernel.registerProvider((any ProjectRAGProviding).self, spy)
        let plugin = ProjectsPlugin()

        _ = plugin.makeRAGStatusSection(projectPath: "/tmp/project-a", kernel: kernel)
        _ = plugin.makeRAGStatusSection(projectPath: "/tmp/project-b", kernel: kernel)

        #expect(spy.addedCount == 2)
        #expect(spy.cancelledCount == 1, "不可见项目的详情观察者仍在 Provider 中注册")
        #expect(spy.liveCount == 1)
    }
}

@MainActor
private final class SpyRAGProvider: ProjectRAGProviding {
    var isInitialized = true
    var currentProjectPath: String?
    private(set) var addedCount = 0
    private(set) var cancelledCount = 0

    var liveCount: Int { addedCount - cancelledCount }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        addedCount += 1
        return SpyObserverHandle { [weak self] in
            self?.cancelledCount += 1
        }
    }

    func search(
        query: String,
        projectPath: String?,
        topK: Int
    ) async throws -> ProjectRAGResponse {
        ProjectRAGResponse(query: query, results: [])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        nil
    }
}

@MainActor
private final class SpyObserverHandle: ProjectRAGObserverHandle {
    private let onCancel: () -> Void
    private var isCancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }
}
