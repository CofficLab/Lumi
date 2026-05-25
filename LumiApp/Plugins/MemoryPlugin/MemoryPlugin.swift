import AgentToolKit
import Foundation
import PluginMemory
import os

/// Memory 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginMemory.MemoryPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor MemoryPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.memory")

    nonisolated static let emoji = "🧠"
    nonisolated static let verbose: Bool = true

    static let id: String = PluginMemory.MemoryPlugin.id
    static let displayName: String = PluginMemory.MemoryPlugin.displayName
    static let description: String = PluginMemory.MemoryPlugin.description
    static let iconName: String = PluginMemory.MemoryPlugin.iconName
    static let isConfigurable: Bool = PluginMemory.MemoryPlugin.isConfigurable
    static let enable: Bool = PluginMemory.MemoryPlugin.enable
    static var category: PluginCategory { .agent }
    static var order: Int { PluginMemory.MemoryPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = MemoryPlugin()

    init() {
        // 注入 App 层的存储路径到 PluginMemory 的配置
        PluginMemory.MemoryPlugin.config = PluginMemory.MemoryPluginConfig(
            memoryRootURL: AppConfig.getDBFolderURL()
                .appendingPathComponent("Memory", isDirectory: true),
            maxRelevantMemories: MemoryPluginLocalStore.shared.maxRelevantMemories,
            staleThresholdDays: MemoryPluginLocalStore.shared.staleThresholdDays,
            halfLifeDays: MemoryPluginLocalStore.shared.halfLifeDays,
            injectGlobalIndex: MemoryPluginLocalStore.shared.shouldInjectGlobalIndex,
            injectProjectIndex: MemoryPluginLocalStore.shared.shouldInjectProjectIndex
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MemoryPlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 MemoryPlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MemoryPlugin 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ MemoryPlugin 已禁用")
        }
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            PluginMemory.SaveMemoryTool(),
            PluginMemory.RecallMemoryTool(),
            PluginMemory.ListMemoriesTool(),
            PluginMemory.DeleteMemoryTool(),
        ]
    }

    // MARK: - Send Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(MemoryContextSuperSendMiddleware())]
    }
}
