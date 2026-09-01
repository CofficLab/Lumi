import Foundation
import KitAgentTool
import KernelCore
import ProviderStorage
import ProviderToolManager

/// Provides the Agent with a durable, plugin-owned place for plan documents.
@MainActor
public final class AgentPlanStoragePlugin: SuperPlugin {
    public static let pluginID = "com.coffic.lumi.plugin.agent-plan-storage"
    public static let toolNames = ["write_plan", "read_plan", "list_plans", "delete_plan"]
    public static let cleanupInterval: Duration = .seconds(6 * 60 * 60)

    public let id = pluginID
    public let order = 81
    public let dependencies = [
        "com.coffic.lumi.plugin.storage",
        "com.coffic.lumi.plugin.tool-manager",
    ]
    public let metadata = PluginMetadata(
        id: pluginID,
        name: "Agent Plan Storage",
        description: "Persistent plan files and automatic retention cleanup for the Agent.",
        category: .system,
        stage: .stable,
        policy: .required
    )

    private var service: PlanFileStorageService?
    private var cleanupTask: Task<Void, Never>?

    public init() {}

    public var name: String { "Agent Plan Storage" }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: StorageProviding.self)
        }

        let directory = storage
            .pluginDataDirectory(for: "AgentPlanStorage")
            .appendingPathComponent("plans", isDirectory: true)
        let service = try PlanFileStorageService(directory: directory)
        self.service = service

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in makeTools(service: service) {
                toolManager.add(tool, pluginID: id)
            }
        }

        cleanupTask = Task { [service] in
            await service.purgeExpiredFiles()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.cleanupInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await service.purgeExpiredFiles()
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        cleanupTask?.cancel()
        cleanupTask = nil

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for toolName in Self.toolNames {
                toolManager.remove(id: toolName)
            }
        }
        service = nil
    }

    private func makeTools(service: PlanFileStorageService) -> [any SuperAgentTool] {
        [
            WritePlanTool(storage: service),
            ReadPlanTool(storage: service),
            ListPlansTool(storage: service),
            DeletePlanTool(storage: service),
        ]
    }
}
