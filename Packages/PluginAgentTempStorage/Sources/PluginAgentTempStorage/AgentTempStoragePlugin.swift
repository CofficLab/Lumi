import Foundation
import KitAgentTool
import KernelCore
import os
import ProviderStorage
import ProviderToolManager
import LumiLoggingKit
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

    // MARK: - 过期文件定时清理（#509）

    /// 定时清理周期。清理此前只挂在 write/read/list 工具调用上，没有工具
    /// 操作时过期文件会无限滞留；启动清理 + 每小时巡检保证承诺的自动删除。
    nonisolated static let purgeInterval: Duration = .seconds(3600)

    private var purgeScheduler: ExpiredTempFilePurgeScheduler?

    /// 启动即清理一次过期文件，并按 `purgeInterval` 周期巡检（#509）。
    private func startExpiredFilePurge() {
        let scheduler = ExpiredTempFilePurgeScheduler(interval: Self.purgeInterval) {
            do {
                try await TempFileStorageService.shared.purgeExpiredFiles()
            } catch {
                Self.logger.error("\(Self.t)Scheduled temp file purge failed: \(String(describing: error))")
            }
        }
        scheduler.start()
        purgeScheduler = scheduler
    }

    public func migrateData(context: PluginDataMigrationContext) throws {
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // 早期回退路径没有版本目录，仍需在首次升级时保留并复制其内容。
        let legacyDirectory = Self.legacyFallbackRootDirectoryProvider()
            .appendingPathComponent("AgentTempStorage", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyDirectory.path) {
            try FileManager.default.createDirectory(
                at: context.currentPluginDataDirectory,
                withIntermediateDirectories: true
            )
            try PluginDataMigrationUtility.mergeDirectoryContents(
                from: legacyDirectory,
                to: context.currentPluginDataDirectory
            )
        }

        // 保留天数此前存在 UserDefaults，是独立于旧文件目录的配置。无论无版本
        // 旧目录是否存在都必须导入：若被上面的目录守卫短路，仅升级版本目录的
        // 用户会静默回退到默认 7 天，后续清理可能误删用户本想保留的文件（#811）。
        importLegacyRetentionDays(to: context.currentPluginDataDirectory)
    }

    /// 读取旧版保留天数所在的 UserDefaults 域。
    ///
    /// 抽成可替换入口，便于单测注入假域：测试进程里 `Bundle.main` 是 xctest
    /// 可执行文件（没有 bundle identifier），拿不到 app 的持久化域。
    nonisolated(unsafe) static var legacyDefaultsDomainProvider: () -> [String: Any]? = {
        UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }

    /// 无版本旧目录的根（迁移时检查 `<root>/AgentTempStorage` 是否存在）。
    /// 抽成可替换入口，便于单测确定性地构造「仅有版本目录」的升级场景，
    /// 不依赖开发者本机 Application Support 的真实状态。
    nonisolated(unsafe) static var legacyFallbackRootDirectoryProvider: () -> URL = {
        AgentTempStoragePluginRuntimeBridge.productionFallbackRootDirectory
    }

    /// 把 `UserDefaults.standard` 中的旧保留天数导入插件专属存储。
    private func importLegacyRetentionDays(to directory: URL) {
        guard let domain = Self.legacyDefaultsDomainProvider(),
              let legacyValue = domain["AgentTempStorage.retentionDays"] as? Int
        else {
            return
        }
        let store = AgentTempStoragePluginLocalStore(settingsDirectory: directory)
        let fileURL = directory.appendingPathComponent("settings.plist")
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        store.retentionDays = legacyValue
        Self.logger.info("\(Self.t)Imported legacy retentionDays from UserDefaults: \(legacyValue)")
    }

    public var name: String {
        pluginLocalization.string("Agent Temp Storage")
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

        startExpiredFilePurge()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        purgeScheduler?.stop()
        purgeScheduler = nil
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
