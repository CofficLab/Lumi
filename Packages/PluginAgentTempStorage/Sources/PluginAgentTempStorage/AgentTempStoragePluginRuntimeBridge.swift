import Foundation
import KitTestIsolation

/// AgentTempStoragePlugin 运行时桥接
///
/// 持有 plugin 专属数据目录,供 TempFileStorageService 和 AgentTempStoragePluginLocalStore 读取
enum AgentTempStoragePluginRuntimeBridge {
    /// `onBoot` 注入的插件数据目录。未注入时为 `nil`。
    nonisolated(unsafe) static var pluginDirectory: URL?

    /// 生产环境兜底数据根目录（仅供 legacy 目录迁移读取）。
    static let productionFallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()

    /// 插件数据目录。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
    static var resolvedPluginDirectory: URL {
        IsolatedDirectoryGuard.directory(
            injected: pluginDirectory,
            owner: "AgentTempStoragePluginRuntimeBridge",
            accessor: "resolvedPluginDirectory",
            fallback: { productionFallbackPluginDirectory }
        )
    }

    /// 生产环境兜底插件目录。
    static let productionFallbackPluginDirectory: URL = {
        #if DEBUG
        let versionedRoot = productionFallbackRootDirectory.appendingPathComponent("db_debug_v6", isDirectory: true)
        #else
        let versionedRoot = productionFallbackRootDirectory.appendingPathComponent("db_production_v6", isDirectory: true)
        #endif
        return versionedRoot.appendingPathComponent(
            "com.coffic.lumi.plugin.agent-temp-storage",
            isDirectory: true
        )
    }()
}
