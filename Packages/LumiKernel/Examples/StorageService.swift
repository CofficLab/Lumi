import Foundation
import LumiKernel

/// 存储服务的具体实现
///
/// 这个类实现了 LumiKernel 的 StorageProviding 协议，
/// 提供具体的存储功能。
@MainActor
public final class StorageService: StorageProviding {

    // MARK: - Properties

    public let dataRootDirectory: URL

    // MARK: - Initialization

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: dataRootDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - StorageProviding

    public func pluginDataDirectory(for pluginID: String) -> URL {
        let pluginDir = dataRootDirectory
            .appendingPathComponent("Plugins", isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)

        // 确保插件目录存在
        try? FileManager.default.createDirectory(
            at: pluginDir,
            withIntermediateDirectories: true
        )

        return pluginDir
    }

    public func coreDataDirectory() -> URL {
        let coreDir = dataRootDirectory
            .appendingPathComponent("Core", isDirectory: true)

        // 确保核心目录存在
        try? FileManager.default.createDirectory(
            at: coreDir,
            withIntermediateDirectories: true
        )

        return coreDir
    }
}