import Foundation
import KernelCore

// MARK: - 上层声明的 Provider 协议（不属于 KernelCore）

/// 存储能力
protocol StorageProviding: AnyObject {
    func pluginDataDirectory(for pluginID: String) -> URL
}

/// 项目管理
protocol ProjectProviding: AnyObject {
    var currentProjectPath: String? { get }
}

// MARK: - 具体实现（由插件/宿主提供）

final class StorageService: StorageProviding {
    func pluginDataDirectory(for pluginID: String) -> URL {
        URL(fileURLWithPath: "/tmp/lumi/plugins/\(pluginID)")
    }
}

final class ProjectService: ProjectProviding {
    var currentProjectPath: String? = "/Users/me/Code/MyApp"
}

// MARK: - 直接使用示例

@MainActor
func directUsageExample() throws {
    // 1. 创建最小核心
    let core = KernelCore()

    // 2. 注册 Provider（简单明了）
    try core.registerProvider(StorageProviding.self, StorageService())
    try core.registerProvider(ProjectProviding.self, ProjectService())

    // 3. 访问 Provider（通过协议）
    if let storage = core.resolveProvider(StorageProviding.self) {
        print(storage.pluginDataDirectory(for: "my-plugin"))
    }

    if let project = core.resolveProvider(ProjectProviding.self) {
        print(project.currentProjectPath ?? "no project")
    }

    // 4. 查询 / 注销
    print("registered count:", core.registeredProviderCount)          // 2
    print("has project:", core.isProviderRegistered(ProjectProviding.self)) // true
    core.unregisterProvider(ProjectProviding.self)
    print("has project:", core.isProviderRegistered(ProjectProviding.self)) // false
}
