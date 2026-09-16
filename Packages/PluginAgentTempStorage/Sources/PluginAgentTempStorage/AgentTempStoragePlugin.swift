import Foundation
import KitAgentTool
import KernelCore
import os
import ProviderStorage
import ProviderToolManager
import KitSuperLog

/// Agent Temp Storage 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/AgentTempStoragePlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 纯工具型插件：`onBoot` 从 `StorageProviding` 配置插件数据目录，并向
/// `ToolManagerProviding` 注册 3 个工具（list / read / write temp file）。
@MainActor
public final class AgentTempStoragePlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    public let id = "com.coffic.lumi.plugin.agent-temp-storage"
    public let legacyDataDirectoryNames = ["AgentTempStorage"]
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.agent-temp-storage",
        name: "Agent Temp Storage",
        description: "",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-temp-storage")

    public init() {}

    public func migrateData(context: PluginDataMigrationContext) throws {
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // 早期回退路径没有版本目录，仍需在首次升级时保留并复制其内容。
        let legacyDirectory = AgentTempStoragePluginRuntimeBridge.fallbackRootDirectory
            .appendingPathComponent("AgentTempStorage", isDirectory: true)
        guard FileManager.default.fileExists(atPath: legacyDirectory.path) else { return }
        try FileManager.default.createDirectory(
            at: context.currentPluginDataDirectory,
            withIntermediateDirectories: true
        )
        try PluginDataMigrationUtility.mergeDirectoryContents(
            from: legacyDirectory,
            to: context.currentPluginDataDirectory
        )
    }

    public var name: String {
        LumiPluginLocalization.string("Agent Temp Storage", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        // 配置插件数据目录（沿用旧版 onReady 的 storage 配置）。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            AgentTempStoragePluginRuntimeBridge.pluginDirectory = storage.pluginDataDirectory(for: id)
        }

        // 注册 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        ListTempFilesTool(),
        ReadTempFileTool(),
        WriteTempFileTool(),
    ]
}
