import Foundation
import KernelCore
import LumiLoggingKit
import ProviderStorage
import ProviderTheme
import os

/// 主题管理插件。
///
/// 负责创建并注册 `ThemeProviding`，同时把用户选中的主题持久化到
/// 自己的插件数据目录。主题包（`ThemePackPlugin`）只负责向这里注册主题，
/// 不再自行创建 Provider。
///
/// 策略为 `required`：主题是应用的基础外观能力，不应被禁用。
/// 宿主可通过 `init(id:)` 传入自己的插件标识，持久化目录随之切换。
@MainActor
public final class ThemeManagerPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.theme-manager",
        category: "ThemeManager"
    )

    /// 默认插件标识（Lumi）。宿主可传入自己的 id。
    public static let defaultPluginID = "com.coffic.lumi.plugin.theme-manager"

    public let id: String
    public let order = 4
    public let metadata: PluginMetadata

    /// 旧版使用的目录名；`ThemeManager` 早于插件 ID 化的目录约定。
    public let legacyDataDirectoryNames = ["ThemeManager"]

    private var provider: DefaultThemeProviding?

    /// 创建主题管理插件。
    ///
    /// - Parameter id: 插件唯一标识，决定持久化目录 `pluginDataDirectory(for:)`。
    public init(id: String = ThemeManagerPlugin.defaultPluginID) {
        self.id = id
        self.metadata = PluginMetadata(
            id: id,
            name: LumiPluginLocalization.string("Theme Manager", bundle: .module),
            description: LumiPluginLocalization.string(
                "Provides theme registration, switching, and persistence.",
                bundle: .module
            ),
            category: .design,
            stage: .stable,
            policy: .required
        )
    }

    // MARK: - 数据迁移

    /// 三个历史布局的迁移，各自独立守卫、互不冲突：
    /// 1. 版本目录之间：`db_*_vN/ThemeManager` → `db_*_vM/<pluginID>`；
    /// 2. 6.0.0 早期构建：同版本根内的 `db_*_v6/ThemeManager`（Lumi 布局）；
    /// 3. 早期非版本化布局：`<Application Support>/<bundleID>/ThemeManager`
    ///    （早期 Kuzee 布局）。
    public func migrateData(context: PluginDataMigrationContext) throws {
        // 1. 版本目录之间：db_*_vN/ThemeManager → db_*_vM/<pluginID>。
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // 2. 同版本根内的 ThemeManager 目录（Lumi 6.0.0 早期构建）。
        try Self.mergeLegacyDirectory(
            at: context.currentDataRootDirectory
                .appendingPathComponent("ThemeManager", isDirectory: true),
            context: context
        )

        // 3. 数据根父级的非版本化 ThemeManager 目录（早期 Kuzee 布局）。
        try Self.mergeLegacyDirectory(
            at: context.currentDataRootDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("ThemeManager", isDirectory: true),
            context: context
        )
    }

    /// 把一个历史目录合并进插件数据目录；目录不存在时静默跳过。
    private static func mergeLegacyDirectory(
        at legacyDirectory: URL,
        context: PluginDataMigrationContext
    ) throws {
        let destination = context.currentPluginDataDirectory
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyDirectory.path),
              legacyDirectory.standardizedFileURL != destination.standardizedFileURL else {
            return
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try PluginDataMigrationUtility.mergeDirectoryContents(
            from: legacyDirectory,
            to: destination,
            fileManager: fileManager
        )
    }

    // MARK: - 生命周期

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any StorageProviding).self)
        }

        let provider = DefaultThemeProviding(
            storageDirectory: storage.pluginDataDirectory(for: id)
        )

        // 兼容宿主或测试注入的旧 ThemeProviding：保留其主题与选中状态，
        // 保证内置主题与本插件的持久化状态都不丢失。
        if let existing = kernel.resolveProvider((any ThemeProviding).self) {
            for theme in existing.themes {
                provider.registerTheme(theme)
            }
            if let selectedThemeId = existing.selectedThemeId {
                try? provider.selectTheme(id: selectedThemeId)
            }
            kernel.unregisterProvider((any ThemeProviding).self)
        }

        // 保留 host provider，使同一个 Kernel 可以 stop 后重新 start；下次
        // onBoot 会读取持久化状态并以新的实例接管它。
        try kernel.registerHostProvider((any ThemeProviding).self, provider)
        self.provider = provider
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        provider = nil
    }
}
