import Foundation
import KitTestIsolation

/// ComputerUse 插件的运行时配置（KernelCore 体系）。
///
/// 存储目录由主插件在 `onBoot` 中从 `StorageProviding` 注入。
@MainActor
enum ComputerUseRuntime {
    /// `onBoot` 注入的插件数据目录。未注入时为 `nil`。
    nonisolated(unsafe) static var injectedSettingsDirectory: URL?

    nonisolated static func settingsDirectory() -> URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedSettingsDirectory,
            owner: "ComputerUseRuntime",
            accessor: "settingsDirectory()",
            fallback: { productionFallbackDirectory }
        )
    }

    nonisolated static func configure(settingsDirectory: URL) {
        injectedSettingsDirectory = settingsDirectory
    }

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
