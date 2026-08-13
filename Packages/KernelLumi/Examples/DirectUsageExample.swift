import Foundation
import KernelLumi

// MARK: - 使用示例

/// 示例：如何使用 KernelLumi
@main
struct KernelLumiUsageExample {

    static func main() async throws {
        // ========== 1. 创建核心 ==========
        let kernel = KernelLumi()

        // ========== 2. 准备数据目录 ==========
        let dataRoot = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Lumi", isDirectory: true)

        // ========== 3. 创建并注册服务（直接明了）==========

        // 方式一：创建实例后注册
        let storage = StorageService(dataRootDirectory: dataRoot)
        try kernel.registerStorage(storage)

        // 方式二：直接创建并注册（一行搞定）
        try kernel.registerProject(ProjectService())
        try kernel.registerWorkspace(LayoutService())

        // ========== 4. 使用服务 ==========
        if let storage = kernel.storage {
            print("Data root: \(storage.dataRootDirectory.path)")

            let pluginDir = storage.pluginDataDirectory(for: "my-plugin")
            print("Plugin directory: \(pluginDir.path)")
        }

        // ========== 5. 注意：重复注册会抛出错误 ==========
        // 如果需要替换某个服务，需要先 unregister 再 register
        // try kernel.registerStorage(AnotherStorageService(dataRootDirectory: dataRoot))  // 会抛出错误

        print("✅ KernelLumi initialized successfully!")
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
    var openFileURLs: [URL] { [] }
    var projects: [ProjectInfo] { [] }

    func openProject(at path: String) async throws {}
    func updateOpenFiles(_ fileURLs: [URL]) {}
    func updateCurrentFile(_ fileURL: URL?) {}
    func closeFile(_ fileURL: URL) {}
    func closeProject() async {}
    func refreshProjects() async throws {}
}

@MainActor
private final class LayoutService: WorkspaceProviding {
    var currentViewContainer: ViewContainerItem? { nil }
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
