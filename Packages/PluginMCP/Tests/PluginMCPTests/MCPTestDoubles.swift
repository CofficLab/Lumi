import Foundation
import ProviderStorage

/// PluginMCP 测试共用的 Provider 替身。
enum MCPTestDoubles {

    /// 指向临时目录的存储替身，并记录插件请求过的数据目录。
    ///
    /// 插件的运行时目录由 `onBoot` 从 `StorageProviding` 解析；测试进程里守卫
    /// 拒绝回退到本机真实数据目录，因此 boot 用例必须提供真实（临时目录）的
    /// 存储 Provider。记录请求过的目录，用来断言插件确实走了注入路径。
    final class StubStorageProvider: StorageProviding {
        let root: URL

        private let lock = NSLock()
        private var requested: [String: URL] = [:]

        init(root: URL) {
            self.root = root
        }

        var dataRootDirectory: URL { root }

        func pluginDataDirectory(for pluginID: String) -> URL {
            let directory = root.appendingPathComponent(pluginID, isDirectory: true)
            lock.withLock { requested[pluginID] = directory }
            return directory
        }

        func coreDataDirectory() -> URL {
            root.appendingPathComponent("core", isDirectory: true)
        }

        /// 插件请求过的数据目录，按插件 ID 索引。
        var requestedPluginDirectories: [String: URL] {
            lock.withLock { requested }
        }
    }

    /// 创建一个本次测试独占的临时目录。
    static func makeTemporaryDirectory(_ label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginMCPTests-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
