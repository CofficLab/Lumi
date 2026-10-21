import Foundation
import LumiLoggingKit
import KitTestIsolation
import os

/// Shared runtime state retained by the V2 App Manager plugin.
/// The old LumiPlugin entry point used to own these values; the migrated
/// lifecycle now lives in AppManagerPlugin.
public enum AppManagerPluginSupport {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    nonisolated public static let verbose = false
    nonisolated public static let railTabID = "app-manager.sidebar"

    /// `onBoot` 注入的插件数据目录。未注入时为 `nil`。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
    nonisolated(unsafe) public static var injectedPluginDataDirectory: URL?

    /// 插件数据目录。
    public static func pluginDataDirectory() -> URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedPluginDataDirectory,
            owner: "AppManagerPluginSupport",
            accessor: "pluginDataDirectory()",
            fallback: { AppManagerPluginRuntimeBridge.productionFallbackPluginDataDirectory }
        )
    }
}

enum AppManagerPluginRuntimeBridge {
    /// 生产环境兜底插件目录。
    static let productionFallbackPluginDataDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 6
        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)
            .appendingPathComponent("com.coffic.lumi.plugin.app-manager", isDirectory: true)
    }()
}
