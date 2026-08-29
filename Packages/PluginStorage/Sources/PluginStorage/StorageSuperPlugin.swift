import Foundation
import KernelCore
import ProviderStorage
import KitSuperLog
import os

// MARK: - Storage SuperPlugin

/// 存储插件
///
/// 创建数据根目录并注册 `StorageService`（`StorageProviding` 实现）。
/// 路径格式：<Application Support>/<bundleID>/db_<debug|production>_v<majorVersion>
@MainActor
public final class StorageSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.storage", category: "Storage")
    public let id = "com.coffic.lumi.plugin.storage"
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.storage",
        name: "Storage Super",
        description: "",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )


    /// 数据根目录
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL? = nil) throws {
        if let dataRootDirectory {
            self.dataRootDirectory = dataRootDirectory
        } else {
            self.dataRootDirectory = try Self.makeDefaultDataRootDirectory()
        }
    }

    public convenience init() throws {
        try self.init(dataRootDirectory: nil)
    }

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelCoreContainer) throws {
        let service = StorageService(dataRootDirectory: dataRootDirectory)
        kernel.unregisterProvider((any StorageProviding).self)
        try kernel.registerProvider((any StorageProviding).self, service)
    }

    // MARK: - Factory

    private static func makeDefaultDataRootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 4

        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif

        let dataRoot = appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)

        try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        return dataRoot
    }
}

// MARK: - StorageService

/// 存储服务实现
@MainActor
public final class StorageService: StorageProviding {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory.standardizedFileURL
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let pluginDir = dataRootDirectory
            .appendingPathComponent(pluginID, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: pluginDir,
            withIntermediateDirectories: true
        )

        return pluginDir
    }

    public func coreDataDirectory() -> URL {
        let coreDir = dataRootDirectory
            .appendingPathComponent("Core", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: coreDir,
            withIntermediateDirectories: true
        )

        return coreDir
    }
}
