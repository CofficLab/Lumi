import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderStorage

/// Registers the shared `StorageProviding` implementation used by CofficLab
/// sibling applications.
///
/// The default path is:
/// `<Application Support>/<bundle identifier>/db_<debug|production>_v<major>`.
/// Hosts that need an isolated or test location can pass an explicit root.
@MainActor
public final class StorageSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.storage",
        category: "Storage"
    )

    public let id = "com.coffic.lumi.plugin.storage"
    public let order = 1
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.storage",
        name: "Storage Super",
        description: "",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL? = nil) throws {
        if let dataRootDirectory {
            self.dataRootDirectory = dataRootDirectory.standardizedFileURL
        } else {
            self.dataRootDirectory = try Self.makeDefaultDataRootDirectory()
        }
    }

    public convenience init() throws {
        try self.init(dataRootDirectory: nil)
    }

    /// 尝试创建插件；默认数据根目录不可用时返回 `nil` 而不是终止进程。
    ///
    /// 宿主工厂在 `makePlugins()` 里使用它：没有存储插件时宿主仍可启动，
    /// 只是失去持久化能力 —— 比用 `try!` 直接杀掉进程更可接受。
    public static func makeIfAvailable(
        builder: (() throws -> StorageSuperPlugin)? = nil
    ) -> StorageSuperPlugin? {
        do {
            return try builder?() ?? StorageSuperPlugin()
        } catch {
            logger.error(
                "创建 StorageSuperPlugin 失败，宿主将以无持久化模式继续：\(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    /// Registers storage unless the host has already provided an explicit
    /// implementation. This lets tests and specialized hosts opt into their
    /// own root without the shared plugin overwriting it.
    public func onBoot(kernel: KernelCoreContainer) throws {
        if let existing = kernel.resolveProvider((any StorageProviding).self) {
            Self.logger.info(
                "\(Self.t)StorageProviding already registered (\(String(describing: type(of: existing)), privacy: .public)); keeping it"
            )
            return
        }

        let service = StorageService(dataRootDirectory: dataRootDirectory)
        try kernel.registerProvider((any StorageProviding).self, service)
    }

    private static func makeDefaultDataRootDirectory() throws -> URL {
        try StoragePathResolver.defaultDataRootDirectory()
    }
}

/// Default storage service backed by a single application data root.
@MainActor
public final class StorageService: StorageProviding {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory.standardizedFileURL
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let pluginDirectory = dataRootDirectory
            .appendingPathComponent(pluginID, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: pluginDirectory,
            withIntermediateDirectories: true
        )

        return pluginDirectory
    }

    public func coreDataDirectory() -> URL {
        let coreDirectory = dataRootDirectory
            .appendingPathComponent("Core", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: coreDirectory,
            withIntermediateDirectories: true
        )

        return coreDirectory
    }
}
