import Foundation
import KitTestIsolation

/// MLX Provider 插件的运行时配置（KernelCore 体系）。
///
/// 存储目录由主插件在 `onBoot` 中从 `StorageProviding` 注入，
/// 与 MLXModelPaths / MLXDownloadManager / MLXRuntime 共用同一根目录。
@MainActor
enum MLXProviderRuntime {
    /// `onBoot` 注入的插件数据目录。未注入时为 `nil`。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
    nonisolated(unsafe) static var injectedSettingsDirectory: URL?

    nonisolated static func settingsDirectory() -> URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedSettingsDirectory,
            owner: "MLXProviderRuntime",
            accessor: "settingsDirectory()",
            fallback: { productionFallbackDataRootDirectory }
        )
    }

    nonisolated static func configure(settingsDirectory: URL) {
        injectedSettingsDirectory = settingsDirectory
    }

    /// 生产环境兜底数据根目录。
    private nonisolated static let productionFallbackDataRootDirectory: URL = {
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
        injectedSettingsDirectory = nil
    }
}
