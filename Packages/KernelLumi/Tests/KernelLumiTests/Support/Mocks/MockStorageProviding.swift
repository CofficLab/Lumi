import Foundation
@testable import KernelLumi

/// 测试用 `StorageProviding` 实现:在临时目录下提供插件/Core 数据目录。
@MainActor
final class MockStorageProviding: StorageProviding {
    let dataRootDirectory: URL

    init(dataRootDirectory: URL = FileManager.default.temporaryDirectory) {
        self.dataRootDirectory = dataRootDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}
