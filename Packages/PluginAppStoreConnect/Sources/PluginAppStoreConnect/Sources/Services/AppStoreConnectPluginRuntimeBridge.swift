import Foundation
import KitTestIsolation
import KernelCore
import ProviderStorage

/// Small, concurrency-safe bridge for services that are intentionally created
/// before the plugin lifecycle has a chance to inject the storage provider.
enum AppStoreConnectPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    nonisolated(unsafe) static var pluginSubdirectory: URL?

    static let pluginName = "AppStoreConnectPlugin"

    /// 生产环境兜底数据根目录（仅供 legacy 目录迁移读取）。
    static let productionFallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()

    /// 生产环境兜底插件目录。
    static let productionFallbackPluginDirectory: URL = {
        #if DEBUG
        let versionedRoot = productionFallbackRootDirectory.appendingPathComponent("db_debug_v6", isDirectory: true)
        #else
        let versionedRoot = productionFallbackRootDirectory.appendingPathComponent("db_production_v6", isDirectory: true)
        #endif
        return versionedRoot
            .appendingPathComponent("com.coffic.lumi.plugin.app-store-connect", isDirectory: true)
    }()

    /// 插件数据目录。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
    static var resolvedPluginDirectory: URL {
        IsolatedDirectoryGuard.directory(
            injected: pluginSubdirectory,
            owner: "AppStoreConnectPluginRuntimeBridge",
            accessor: "resolvedPluginDirectory",
            fallback: { productionFallbackPluginDirectory }
        )
    }

    @MainActor
    static func configure(kernel: KernelCoreContainer, pluginID: String) {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        dataRootDirectory = storage.dataRootDirectory
        pluginSubdirectory = storage.pluginDataDirectory(for: pluginID)
    }
}
