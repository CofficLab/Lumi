import Foundation
import KernelCore
import KitSuperLog
import ProviderStorage
import ProviderTheme
import os

/// 主题管理插件。
///
/// 负责创建并注册 `ThemeProviding`，同时持久化当前选中的主题。主题包
/// （`ThemePackPlugin`）只负责向这里注册主题，不再由 ProviderFactory 预注册
/// 一个独立的 ThemeManager 目录。
@MainActor
public final class ThemeManagerPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.theme-manager",
        category: "ThemeManager"
    )

    public static let pluginID = "com.coffic.lumi.plugin.theme-manager"

    public let id = "com.coffic.lumi.plugin.theme-manager"
    public let order = 4
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.theme-manager",
        name: "主题管理",
        description: "提供主题注册、切换与持久化能力。",
        category: .design,
        stage: .stable,
        policy: .required
    )

    /// v4/v5 以及早期 v6 实现使用的目录名。
    public let legacyDataDirectoryNames = ["ThemeManager"]

    private var provider: DefaultThemeProviding?

    public init() {}

    public func migrateData(context: PluginDataMigrationContext) throws {
        // 迁移 v4/v5 的版本根目录：<root>/ThemeManager -> <root>/<pluginID>。
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // 6.0.0 早期构建已经使用了 db_*_v6/ThemeManager；它不在 legacy
        // 根目录列表中，因此需要在同一版本根目录内额外迁移一次。
        let currentLegacyDirectory = context.currentDataRootDirectory
            .appendingPathComponent("ThemeManager", isDirectory: true)
        let destination = context.currentPluginDataDirectory
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: currentLegacyDirectory.path),
              currentLegacyDirectory.standardizedFileURL != destination.standardizedFileURL else {
            return
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try PluginDataMigrationUtility.mergeDirectoryContents(
            from: currentLegacyDirectory,
            to: destination,
            fileManager: fileManager
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any StorageProviding).self)
        }

        let provider = DefaultThemeProviding(
            storageDirectory: storage.pluginDataDirectory(for: id)
        )

        // 兼容专用宿主或测试注入的旧 ThemeProviding，同时保留其主题与选中状态。
        if let existing = kernel.resolveProvider((any ThemeProviding).self) {
            for theme in existing.themes {
                provider.registerTheme(theme)
            }
            if let selectedThemeId = existing.selectedThemeId {
                try? provider.selectTheme(id: selectedThemeId)
            }
            kernel.unregisterProvider((any ThemeProviding).self)
        }

        try kernel.registerHostProvider((any ThemeProviding).self, provider)
        self.provider = provider
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 保留 host provider，使同一个 Kernel 可以 stop 后重新 start；下次
        // onBoot 会读取持久化状态并以新的实例接管它。
        provider = nil
    }
}
