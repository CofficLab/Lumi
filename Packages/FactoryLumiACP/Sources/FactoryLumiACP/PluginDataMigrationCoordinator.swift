import Foundation
import KernelCore
import os
import ProviderStorage

/// 在插件启动前统一运行插件自己的数据迁移。
@MainActor
struct PluginDataMigrationCoordinator {
    static let currentMajorVersion = 6

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "kernel.data-migration"
    )
    nonisolated static let emoji = "📦"

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

    /// 逐个运行插件迁移。
    ///
    /// 迁移失败**不阻断启动**：单个插件的历史数据搬不动，最多意味着该插件退回
    /// 默认配置，不应让整个 App 起不来。逐个隔离后，一个坏插件也不会连带
    /// 阻断其他插件的迁移。
    func run(for plugins: [any SuperPlugin]) {
        for plugin in plugins {
            do {
                try PluginDataMigrationRunner(storage: storage).run(for: [plugin])
            } catch {
                Self.logger.error(
                    "\(Self.emoji) | PluginDataMigrationCoordinator | 插件 \(plugin.id, privacy: .public) 数据迁移失败，已跳过并继续启动：\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
