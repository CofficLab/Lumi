import Foundation
import ProjectRAGEngine
import ProviderProject
import ProviderProjectRAG

/// `RAGService` 的 Kernel Provider 适配器。
@MainActor
public final class ProjectRAGProvider: ProjectRAGProviding {
    private let service: RAGService
    private weak var project: (any ProjectProviding)?
    private var observers: [UUID: (ProjectRAGEvent) -> Void] = [:]
    private var projectObserver: (any ProjectProvidingObserverHandle)?

    public init(service: RAGService, project: (any ProjectProviding)?) {
        self.service = service
        self.project = project
        projectObserver = project?.addObserver { [weak self] event in
            guard case .currentProjectChanged = event, let self else { return }
            self.notify(.projectChanged(self.currentProjectPath))
        }
    }

    @discardableResult
    public func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProjectRAGObserverHandleImpl { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public var isInitialized: Bool { service.isInitialized }
    public var currentProjectPath: String? { project?.workspaceRoot }

    public func isIndexing(projectPath: String) -> Bool {
        RAGService.isIndexing(projectPath: projectPath)
    }

    public func search(
        query: String,
        projectPath: String?,
        topK: Int
    ) async throws -> ProjectRAGResponse {
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

    private func notify(_ event: ProjectRAGEvent) {
        for callback in observers.values {
            callback(event)
        }
    }
}

@MainActor
private final class ProjectRAGObserverHandleImpl: ProjectRAGObserverHandle {
    private let cancellation: () -> Void
    private var isCancelled = false

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        cancellation()
    }
}
