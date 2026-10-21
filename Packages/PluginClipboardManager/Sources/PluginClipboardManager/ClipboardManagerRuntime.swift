import Foundation
import KitTestIsolation

/// ClipboardManager 插件的运行时目录持有。
///
/// 目录由主插件在 `onBoot` 中从 `StorageProviding` 注入。
/// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
public enum ClipboardManagerRuntime {
    /// `onBoot` 注入的插件数据目录。未注入时为 `nil`。
    nonisolated(unsafe) public static var injectedDatabaseDirectory: URL?

    /// 插件数据目录。
    public static func databaseDirectory() -> URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedDatabaseDirectory,
            owner: "ClipboardManagerRuntime",
            accessor: "databaseDirectory()",
            fallback: { productionFallbackDataRootDirectory }
        )
    }

    /// 生产环境兜底数据根目录。
    private static let productionFallbackDataRootDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #if DEBUG
        let versionedRoot = "db_debug_v6"
        #else
        let versionedRoot = "db_production_v6"
        #endif
        return base
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent(versionedRoot, isDirectory: true)
    }()
}
