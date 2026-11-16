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

    /// 图片负载的持久目录：`<dataRoot>/images`。
    ///
    /// 剪贴板历史是持久 SwiftData，图片若落在系统临时目录，会被系统清理，
    /// 留下永久损坏、重启也无法恢复的历史条目（#242）。图片必须与数据库
    /// 同住在插件自有的持久目录里。
    public static func imageDirectory() -> URL {
        databaseDirectory().appendingPathComponent("images", isDirectory: true)
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
