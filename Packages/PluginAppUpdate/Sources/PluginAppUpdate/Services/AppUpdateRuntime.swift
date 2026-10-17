import Foundation

/// App Update 插件的运行时配置（KernelCore 体系）。
///
/// 存储目录由主插件在 `onBoot` 中从 `StorageProviding` 注入。
@MainActor
enum AppUpdateRuntime {
    /// 插件数据目录。存根回退路径仅用于插件尚未 boot 的极早期访问，
    /// 形状与内核 `StorageProviding` 的版本化数据根保持一致。
    nonisolated(unsafe) static var settingsDirectoryProvider: () -> URL = {
        fallbackDataRootDirectory
            .appendingPathComponent("com.coffic.lumi.plugin.app-update", isDirectory: true)
    }

    nonisolated static func settingsDirectory() -> URL {
        settingsDirectoryProvider()
    }

    nonisolated static func configure(settingsDirectory: URL) {
        settingsDirectoryProvider = { settingsDirectory }
    }

    private nonisolated static let fallbackDataRootDirectory: URL = {
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

    static func reset() {
        settingsDirectoryProvider = {
            fallbackDataRootDirectory
                .appendingPathComponent("com.coffic.lumi.plugin.app-update", isDirectory: true)
        }
    }
}
