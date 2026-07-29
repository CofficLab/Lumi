import LumiKernel
import os

/// Memory 插件 OnReady 阶段钩子：绑定插件数据目录并加载本地设置。
@MainActor
public struct MemoryOnReadyHook {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.memory")

    public init() {}

    public func execute(_ kernel: LumiKernel) async throws {
        guard let storage = kernel.storage else {
            Self.logger.error("🧠 Storage service not available")
            return
        }

        let localStore = MemoryPluginLocalStore.shared
        MemoryPlugin.config = MemoryPluginConfig(
            memoryRootURL: storage.pluginDataDirectory(for: "Memory"),
            maxRelevantMemories: localStore.maxRelevantMemories,
            staleThresholdDays: localStore.staleThresholdDays,
            halfLifeDays: localStore.halfLifeDays,
            injectGlobalIndex: localStore.shouldInjectGlobalIndex,
            injectProjectIndex: localStore.shouldInjectProjectIndex,
            autoRecall: localStore.shouldAutoRecall,
            autoSave: localStore.shouldAutoSave
        )
    }
}
