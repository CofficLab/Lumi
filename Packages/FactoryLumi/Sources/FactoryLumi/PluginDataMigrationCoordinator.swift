import Foundation
import KernelCore
import ProviderStorage

/// 在插件启动前统一运行插件自己的数据迁移。
@MainActor
struct PluginDataMigrationCoordinator {
    static let currentMajorVersion = 6

    private let storage: any StorageProviding

    init(storage: any StorageProviding) {
        self.storage = storage
    }

    /// 供在 Provider 创建前就需要读取磁盘的基础设施使用（例如插件启用状态
    /// 和工具调用记录）。这些目录不能等到普通插件 onBoot 后再迁移。
    static func migrateProviderData(
        storage: any StorageProviding,
        pluginID: String,
        legacyDirectoryNames: [String]
    ) throws {
        try StorageDataMigration.migrate(
            storage: storage,
            pluginID: pluginID,
            legacyDirectoryNames: legacyDirectoryNames,
        )
    }

    func run(for plugins: [any SuperPlugin]) throws {
        try PluginDataMigrationRunner(storage: storage).run(for: plugins)
    }
}
