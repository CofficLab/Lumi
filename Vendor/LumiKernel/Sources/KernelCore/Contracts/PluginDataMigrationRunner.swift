import Foundation

/// 在宿主启动插件前，统一运行各插件自己的数据迁移。
///
/// 放在 KernelCore 中，使主应用与任何专用宿主都能复用同一套迁移时序。
/// 每个插件的迁移逻辑由 `PluginDataMigrating` 声明。
@MainActor
public struct PluginDataMigrationRunner {
    public let currentMajorVersion: Int
    private let currentDataRootDirectory: URL
    private let legacyDataRootDirectories: [Int: URL]

    /// - Parameters:
    ///   - currentMajorVersion: 当前宿主数据的主版本号，由宿主负责定义。
    ///   - currentDataRootDirectory: 当前版本的数据根目录。
    ///   - legacyDataRootDirectories: 历史版本根目录（版本号 → 目录）。
    public init(
        currentMajorVersion: Int,
        currentDataRootDirectory: URL,
        legacyDataRootDirectories: [Int: URL] = [:]
    ) {
        self.currentMajorVersion = currentMajorVersion
        self.currentDataRootDirectory = currentDataRootDirectory
        self.legacyDataRootDirectories = legacyDataRootDirectories
    }

    /// 逐个运行插件迁移。
    ///
    /// 未实现 `PluginDataMigrating` 的插件不做处理：它们没有历史数据需要搬运。
    public func run(for plugins: [any SuperPlugin]) throws {
        for plugin in plugins {
            guard let migrator = plugin as? any PluginDataMigrating else { continue }
            try migrator.migrateData(context: context(for: plugin))
        }
    }

    private func context(for plugin: any SuperPlugin) -> PluginDataMigrationContext {
        PluginDataMigrationContext(
            pluginID: plugin.id,
            currentMajorVersion: currentMajorVersion,
            currentDataRootDirectory: currentDataRootDirectory,
            legacyDataRootDirectories: legacyDataRootDirectories
        )
    }
}
