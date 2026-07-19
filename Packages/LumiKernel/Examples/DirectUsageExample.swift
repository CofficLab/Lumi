import Foundation
import LumiKernel

// MARK: - 使用示例

/// 示例：如何使用 LumiKernel
@main
struct LumiKernelUsageExample {

    static func main() async throws {
        // ========== 1. 创建核心 ==========
        let kernel = LumiKernel()

        // ========== 2. 准备数据目录 ==========
        let dataRoot = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Lumi", isDirectory: true)

        // ========== 3. 创建并注册服务（直接明了）==========

        // 方式一：创建实例后注册
        let storage = StorageService(dataRootDirectory: dataRoot)
        kernel.registerStorage(storage)

        // 方式二：直接创建并注册（一行搞定）
        kernel.registerProject(ProjectService())
        kernel.registerLayout(LayoutService())
        kernel.registerChat(ChatService())

        // ========== 4. 使用服务 ==========
        if let storage = kernel.storage {
            print("Data root: \(storage.dataRootDirectory.path)")

            let pluginDir = storage.pluginDataDirectory(for: "my-plugin")
            print("Plugin directory: \(pluginDir.path)")
        }

        // ========== 5. 可选：运行时替换服务 ==========
        // 如果需要替换某个服务，直接重新注册即可
        kernel.registerStorage(AnotherStorageService(dataRootDirectory: dataRoot))

        print("✅ LumiKernel initialized successfully!")
    }
}

// MARK: - 示例服务实现

@MainActor
private final class StorageService: StorageProviding {
    let dataRootDirectory: URL

    init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}

@MainActor
private final class ProjectService: ProjectProviding {
    var currentProject: ProjectInfo? { nil }
    var projects: [ProjectInfo] { [] }

    func openProject(at path: String) async throws {}
    func closeProject() async {}
    func refreshProjects() async throws {}
}

@MainActor
private final class LayoutService: LayoutProviding {
    var state: LayoutStateInfo { LayoutStateInfo() }
    func updateLayout(_ update: (inout LayoutStateInfo) -> Void) {}
}

@MainActor
private final class ChatService: ChatServiceProviding {
    var selectedProviderID: String? { nil }
    func sendMessage(_ content: String, conversationID: UUID) async throws {}
    func cancelCurrentRequest() {}
}

@MainActor
private final class AnotherStorageService: StorageProviding {
    let dataRootDirectory: URL

    init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("AltPlugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("AltCore")
    }
}