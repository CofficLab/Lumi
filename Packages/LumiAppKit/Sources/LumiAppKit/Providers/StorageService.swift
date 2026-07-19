import Foundation
import LumiKernel

/// 存储服务实现
///
/// 实现 LumiKernel 的 StorageProviding 协议，
/// 提供应用级的存储功能。
@MainActor
public final class StorageService: StorageProviding {

    // MARK: - Properties

    public let dataRootDirectory: URL

    // MARK: - Initialization

    public init(dataRootDirectory: URL) throws {
        self.dataRootDirectory = dataRootDirectory.standardizedFileURL

        // 确保根目录存在
        try FileManager.default.createDirectory(
            at: self.dataRootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - StorageProviding

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let pluginDir = dataRootDirectory
            .appendingPathComponent("Plugins", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)

        // 自动创建插件目录
        try? FileManager.default.createDirectory(
            at: pluginDir,
            withIntermediateDirectories: true
        )

        return pluginDir
    }

    public func coreDataDirectory() -> URL {
        let coreDir = dataRootDirectory
            .appendingPathComponent("Core", isDirectory: true)

        // 自动创建核心目录
        try? FileManager.default.createDirectory(
            at: coreDir,
            withIntermediateDirectories: true
        )

        return coreDir
    }
}