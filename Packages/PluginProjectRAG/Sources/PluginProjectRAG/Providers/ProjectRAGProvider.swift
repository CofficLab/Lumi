import Foundation
import ProjectRAGEngine
import ProviderProject
import ProviderProjectRAG

/// `RAGService` 的 Kernel Provider 适配器。
@MainActor
public final class ProjectRAGProvider: ProjectRAGProviding {
    private let service: RAGService
    private weak var project: (any ProjectProviding)?
    /// 弱引用持有令牌：外部释放令牌后即视为自动注销，下次注册或广播时清理。
    private var observers: [WeakProjectRAGObserver] = []

    public init(service: RAGService, project: (any ProjectProviding)?) {
        self.service = service
        self.project = project
    }

    func handleProjectChange() {
        notify(.projectChanged(currentProjectPath))
    }

    @discardableResult
    public func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        observers.removeAll { $0.handle == nil }
        let handle = ProjectRAGObserverHandleImpl(owner: self, callback: callback)
        observers.append(WeakProjectRAGObserver(handle))
        return handle
    }

    public var isInitialized: Bool { service.isInitialized }
    public var currentProjectPath: String? { project?.workspaceRoot }

    public func isIndexing(projectPath: String) -> Bool {
        // RAGService serializes indexing and retrieval through one actor. An
        // index for another project blocks retrieval just as much as an index
        // for this project, so callers must treat the state as process-wide.
        RAGService.isAnyIndexing() || RAGService.isIndexing(projectPath: projectPath)
    }

    public func search(
        query: String,
        projectPath: String?,
        topK: Int
    ) async throws -> ProjectRAGResponse {
        // Do not enter the RAG actor while any project is being indexed. The
        // actor serializes retrieval behind indexing, so this fast path keeps
        // the LLM request independent of background indexing even if the
        // state changes after CodeNavigationCoordinator's initial check.
        guard !RAGService.isAnyIndexing() else {
            return ProjectRAGResponse(query: query, results: [])
        }
        let path = normalizedProjectPath(projectPath)
        try await service.initialize()
        let response = try await service.retrieve(query: query, projectPath: path, topK: topK)
        return ProjectRAGResponse(
            query: response.query,
            results: response.results.map {
                ProjectRAGSearchResult(
                    content: $0.content,
                    source: $0.source,
                    score: $0.score,
                    matchKind: ProjectRAGMatchKind(rawValue: $0.matchKind.rawValue) ?? .semantic,
                    lineRange: $0.lineRange.map {
                        ProjectRAGLineRange(startLine: $0.startLine, endLine: $0.endLine)
                    }
                )
            }
        )
    }

    public func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        // A concurrent index is already making progress. Waiting for it here
        // would put the current LLM request behind an unrelated project.
        guard !RAGService.isAnyIndexing() else { return }
        notify(.indexingStarted(projectPath))
        try await service.initialize()
        notify(.initialized)
        if background {
            await service.ensureIndexedBackground(projectPath: projectPath, force: force)
            notify(.indexingFinished(projectPath))
            return
        }
        try await service.ensureIndexed(projectPath: projectPath, force: force)
        notify(.indexingFinished(projectPath))
    }

    public func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        // `indexStatus` is actor-isolated in RAGService. Avoid enqueueing this
        // read behind a long-running index; the caller will retry after the
        // background work completes.
        guard !RAGService.isAnyIndexing() else { return nil }
        try await service.initialize()
        guard let status = try await service.getIndexStatus(projectPath: projectPath) else { return nil }
        return ProjectRAGIndexStatus(
            projectPath: status.projectPath,
            lastIndexedAt: status.lastIndexedAt,
            fileCount: status.fileCount,
            chunkCount: status.chunkCount,
            isStale: status.isStale
        )
    }

    private func normalizedProjectPath(_ path: String?) -> String? {
        if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return path
        }
        return currentProjectPath
    }

    /// 移除指定观察者（供令牌的 `cancel` 调用）。
    fileprivate func removeObserver(_ handle: ProjectRAGObserverHandleImpl) {
        observers.removeAll { $0.handle === handle }
    }

    private func notify(_ event: ProjectRAGEvent) {
        // 释放令牌的回调不会再收到事件，先清理再复制遍历，避免回调中
        // 注销自身导致集合在遍历期间变化。
        observers.removeAll { $0.handle == nil }
        let liveObservers = observers
        for observer in liveObservers {
            observer.handle?.invoke(event)
        }
    }
}

@MainActor
private final class ProjectRAGObserverHandleImpl: ProjectRAGObserverHandle {
    private weak var owner: ProjectRAGProvider?
    fileprivate let callback: (ProjectRAGEvent) -> Void
    private var isCancelled = false

    init(owner: ProjectRAGProvider, callback: @escaping (ProjectRAGEvent) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeObserver(self)
    }

    fileprivate func invoke(_ event: ProjectRAGEvent) {
        guard !isCancelled else { return }
        callback(event)
    }
}

/// 观察者集合的元素：弱引用持有令牌，令牌被外部释放后自动失效。
@MainActor
private final class WeakProjectRAGObserver {
    fileprivate weak var handle: ProjectRAGObserverHandleImpl?

    init(_ handle: ProjectRAGObserverHandleImpl) {
        self.handle = handle
    }
}
