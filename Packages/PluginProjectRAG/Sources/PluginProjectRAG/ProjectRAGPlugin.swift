import KitAgentTool
import Foundation
import KernelCore
import ProjectRAGEngine
import ProviderProject
import ProviderIdleTime
import ProviderStorage
import ProviderToolManager
import ProviderProjectRAG

/// Project RAG 的 KernelCore 适配器。
///
/// 旧版仅在 LumiApp 注入该插件，迁移到 `LumiMinimalApp` 后遗漏，导致
/// `search_code` 工具和本地项目索引均不可用。此适配器直接使用已去除
/// KernelLumi 耦合的 RAG 引擎，并保留数据库目录 (`RAG`)、SQLite schema
/// 与 vec0 扩展，因此升级不会丢失既有索引。
@MainActor
public final class ProjectRAGSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.project.rag"
    public let order = 70
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.project.rag",
        name: "Project RAG",
        description: "Indexes project code and provides semantic code search.",
        category: .project,
        stage: .experimental,
        policy: .alwaysOn
    )

    private var service: RAGService?
    private var schedulerTask: Task<Void, Never>?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let directory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: "RAG")
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("RAG", isDirectory: true)
        let service = RAGService(databaseDirectoryProvider: { directory })
        self.service = service

        let project = kernel.resolveProvider((any ProjectProviding).self)
        let idleTime = kernel.resolveProvider((any IdleTimeProviding).self)
        let provider = ProjectRAGProvider(service: service, project: project)
        ProjectRAGRuntime.configure(provider: provider)
        try kernel.registerProvider((any ProjectRAGProviding).self, provider)
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .add(RAGCodeSearchTool(), pluginID: id)

        // Indexing deliberately happens off the boot path: startup remains
        // responsive and RAGService deduplicates concurrent index requests.
        schedulerTask = Task(priority: .utility) { [weak project, weak idleTime] in
            do {
                try await service.initialize()
                guard let path = await MainActor.run(body: { project?.currentProject?.path }),
                      !path.isEmpty else { return }
                await service.ensureIndexedBackground(projectPath: path)
                guard let project, let idleTime else { return }
                await RAGIndexScheduler(
                    projects: project,
                    idleTime: idleTime,
                    service: service,
                    stateDirectory: directory
                ).run()
            } catch {
                // Search stays available and can retry indexing on its first use.
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: RAGCodeSearchTool.toolName)
        kernel.unregisterProvider((any ProjectRAGProviding).self)
        schedulerTask?.cancel()
        schedulerTask = nil
        if let service { Task { await service.cancelBackgroundIndexing() } }
        service = nil
        ProjectRAGRuntime.reset()
    }
}

@MainActor
enum ProjectRAGRuntime {
    private(set) static var provider: (any ProjectRAGProviding)?

    static func configure(provider: any ProjectRAGProviding) {
        self.provider = provider
    }

    static func reset() {
        provider = nil
    }

}

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

/// 新旧版本均使用 `search_code` 作为稳定的工具名，避免历史会话、提示词和
/// agent 配置在升级后失效。索引不存在或过期时先增量构建，再进行语义检索。
public struct RAGCodeSearchTool: SuperAgentTool {
    public static let toolName = "search_code"
    public let name = Self.toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Search semantic code snippets in the current project or an explicitly supplied project path."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "A symbol, error, file path, or natural-language code query."],
                "project_path": ["type": "string", "description": "Optional project root. Defaults to the current project."],
                "top_k": ["type": "integer", "minimum": 1, "maximum": 20, "description": "Maximum result count; defaults to 8."],
            ],
            "required": ["query"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let query = (arguments["query"]?.value as? String ?? "code").prefix(40)
        return "Search code: \(query)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let query = (arguments["query"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            return "## Code Search\n\nMissing required `query` parameter."
        }
        let explicitPath = (arguments["project_path"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectPath = explicitPath?.isEmpty == false
            ? explicitPath
            : await MainActor.run { ProjectRAGRuntime.provider?.currentProjectPath }
        guard let projectPath, !projectPath.isEmpty else {
            return "## Code Search\n\nOpen a project or provide `project_path`."
        }
        guard FileManager.default.fileExists(atPath: projectPath) else {
            return "## Code Search\n\nProject path does not exist: `\(projectPath)`"
        }
        guard let provider = await MainActor.run(body: { ProjectRAGRuntime.provider }) else {
            return "## Code Search\n\nProject RAG is not available."
        }

        let topK = min(max((arguments["top_k"]?.value as? Int) ?? 8, 1), 20)
        try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
        let response = try await provider.search(query: query, projectPath: projectPath, topK: topK)
        guard !response.results.isEmpty else {
            return "## Code Search\n\nNo indexed code matched `\(query)`. Indexing may still be in progress."
        }
        return response.results.enumerated().map { index, result in
            let score = String(format: "%.2f", result.score)
            return "### \(index + 1). `\(result.source)` (score: \(score))\n\n```\n\(result.content)\n```"
        }.joined(separator: "\n\n")
    }
}
