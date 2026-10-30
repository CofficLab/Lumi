import Foundation
import ProviderStorage

/// Input Manager 插件测试共用的 Provider 替身。
enum InputPluginTestDoubles {

    /// 指向临时目录的存储替身。
    ///
    /// 插件的运行时目录由 `onBoot` 从 `StorageProviding` 注入；测试进程里
    /// 守卫拒绝回退到本机真实数据目录，因此 boot 相关用例必须提供真实
    /// 的存储 Provider（根落在临时目录）。
    final class StubStorageProvider: StorageProviding {
        let root: URL

        init(root: URL) {
            self.root = root
        }

        var dataRootDirectory: URL { root }

        func pluginDataDirectory(for pluginID: String) -> URL {
            root.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            root.appendingPathComponent("core", isDirectory: true)
        }
    }

    /// 创建一个本次测试独占的临时目录。
    static func makeTemporaryDirectory(_ label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginInputTests-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
