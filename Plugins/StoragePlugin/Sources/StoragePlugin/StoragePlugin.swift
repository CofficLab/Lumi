import Foundation
import LumiKernel

/// 存储插件
///
/// 向 LumiKernel 注册 Storage 服务。
@MainActor
public final class StoragePlugin: LumiPlugin {

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.storage"
    public let name = "Storage Plugin"

    /// 数据根目录
    private let dataRootDirectory: URL

    // MARK: - Initialization

    public init(dataRootDirectory: URL? = nil) throws {
        if let dataRootDirectory {
            self.dataRootDirectory = dataRootDirectory
        } else {
            self.dataRootDirectory = try Self.makeDefaultDataRootDirectory()
        }
    }

    /// 使用默认目录创建
    public convenience init() throws {
        try self.init(dataRootDirectory: nil)
    }

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let storage = StorageService(dataRootDirectory: dataRootDirectory)
        kernel.registerStorage(storage)
    }

    // MARK: - Factory Methods

    private static func makeDefaultDataRootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dataRoot = appSupport.appendingPathComponent("Lumi", isDirectory: true)
        try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        return dataRoot
    }
}

// MARK: - Storage Service

/// 存储服务实现
@MainActor
public final class StorageService: StorageProviding {

    public let dataRootDirectory: URL

    init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory.standardizedFileURL
    }

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let pluginDir = dataRootDirectory
            .appendingPathComponent("Plugins", isDirectory: true)
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