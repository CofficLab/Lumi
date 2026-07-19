import Foundation
import LumiKernel

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
