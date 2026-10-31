import Foundation
import KitAgentTool
import KernelCore
import ProviderStorage
import ProviderToolManager
import os

/// Provides the Agent with a durable, plugin-owned place for plan documents.
@MainActor
public final class AgentPlanStoragePlugin: SuperPlugin, PluginDataMigrating {
    public static let pluginID = "com.coffic.lumi.plugin.agent-plan-storage"
    public let legacyDataDirectoryNames = ["AgentPlanStorage"]
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

    public func migrateData(context: PluginDataMigrationContext) throws {
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // 保留天数此前存在 UserDefaults，仅在插件存储尚无该键时导入。
        importLegacyRetentionDays(to: context.currentPluginDataDirectory)
    }

    /// 把 `UserDefaults.standard` 中的旧保留天数导入插件专属存储。
    private func importLegacyRetentionDays(to directory: URL) {
        guard let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? ""),
              let legacyValue = domain["AgentPlanStorage.retentionDays"] as? Int
        else {
            return
        }
        let fileURL = directory.appendingPathComponent("settings.plist")
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        AgentPlanStoragePluginLocalStore(settingsDirectory: directory).retentionDays = legacyValue
        Self.migrationLogger.info(
            "Imported legacy retentionDays from UserDefaults: \(legacyValue)"
        )
    }

    private static let migrationLogger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.agent-plan-storage.migration"
    )

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: StorageProviding.self)
        }

        // 配置目录注入必须早于 AgentPlanStoragePluginLocalStore.shared 的首次访问。
        AgentPlanStorageRuntime.configure(settingsDirectory: storage.pluginDataDirectory(for: id))

        let directory = storage
            .pluginDataDirectory(for: id)
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
