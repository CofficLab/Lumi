import Foundation
import KitTestIsolation

/// App Update 插件的运行时配置（KernelCore 体系）。
///
/// 存储目录由主插件在 `onBoot` 中从 `StorageProviding` 注入。
@MainActor
enum AppUpdateRuntime {
    /// `onBoot` 注入的插件数据目录。未注入时为 `nil`。
    nonisolated(unsafe) static var injectedSettingsDirectory: URL?

    nonisolated static func settingsDirectory() -> URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedSettingsDirectory,
            owner: "AppUpdateRuntime",
            accessor: "settingsDirectory()",
            fallback: { productionFallbackDirectory }
        )
    }

    nonisolated static func configure(settingsDirectory: URL) {
        injectedSettingsDirectory = settingsDirectory
    }

    /// 生产环境兜底目录。
    ///
    /// - Note: 保留兜底是为了「插件尚未 boot 的极早期访问」这类场景，
    ///   但绝不能让它在测试里生效——那会让测试读写开发者本机的真实数据目录。
    private nonisolated static let productionFallbackDirectory: URL = {
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
