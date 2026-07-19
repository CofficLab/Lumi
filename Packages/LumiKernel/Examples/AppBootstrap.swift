import Foundation
import LumiKernel

/// 应用启动示例
///
/// 展示如何创建 LumiKernel 并注入 Storage 服务。
@main
struct AppBootstrap {

    static func main() async throws {
        // 1. 创建轻量级核心
        let kernel = LumiKernel()

        // 2. 准备数据目录
        let dataRoot = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Lumi", isDirectory: true)

        // 3. 创建服务提供者
        let storageProvider = StorageServiceProvider(dataRootDirectory: dataRoot)

        // 4. 注入服务到核心
        try await kernel.bootstrap(with: [storageProvider])

        // 5. 使用服务（通过协议）
        if let storage = kernel.storage {
            print("Data root: \(storage.dataRootDirectory.path)")

            let pluginDir = storage.pluginDataDirectory(for: "com.example.my-plugin")
            print("Plugin directory: \(pluginDir.path)")

            let coreDir = storage.coreDataDirectory()
            print("Core directory: \(coreDir.path)")
        }

        // 6. 运行应用...
        print("LumiKernel initialized successfully!")
    }
}