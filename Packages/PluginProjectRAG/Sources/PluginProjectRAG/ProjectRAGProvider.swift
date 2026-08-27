import Foundation
import ProjectRAGEngine
import ProviderProject
import ProviderProjectRAG

/// `RAGService` 的 Kernel Provider 适配器。
@MainActor
public final class ProjectRAGProvider: ProjectRAGProviding {
    private let service: RAGService
    private weak var project: (any ProjectProviding)?

    public init(service: RAGService, project: (any ProjectProviding)?) {
        self.service = service
        self.project = project
    }

    public var isInitialized: Bool { service.isInitialized }
    public var currentProjectPath: String? { project?.currentProject?.path }

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
                ProjectRAGSearchResult(content: $0.content, source: $0.source, score: $0.score)
            }
        )
    }

    public func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        try await service.initialize()
        if background {
            await service.ensureIndexedBackground(projectPath: projectPath, force: force)
            return
        }
        try await service.ensureIndexed(projectPath: projectPath, force: force)
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
}
