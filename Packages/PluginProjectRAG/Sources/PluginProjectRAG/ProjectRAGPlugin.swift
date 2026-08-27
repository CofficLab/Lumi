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
