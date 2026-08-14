import Combine
import Foundation
import KernelLumi

/// 思维导图运行时：在 `onBoot` 时绑定存储目录，并监听项目变化以刷新项目作用域。
///
/// 与 `IconDesignerRuntime` 同构：维护 app / project 两个存储目录，
/// `MindMapStore.shared` 通过 `setAppStorage` / `setProjectStorage` 接收路径变化。
@MainActor
enum MindMapRuntime {
    /// APP 内存储目录（应用级别，跨项目共享）。
    static private(set) var appStorageDirectory: URL?

    /// 项目内存储目录（基于当前打开项目，nil 表示无打开项目）。
    static private(set) var projectStorageDirectory: URL?

    /// 当前打开项目的路径（供工具访问与 UI 展示）。
    static private(set) var currentProjectPath: String?

    /// 内核实例（在 `onBoot` 时注入）。
    static private(set) var kernel: KernelLumi?

    private static var projectCancellable: AnyCancellable?

    /// 项目内存储目录的末段名称（`<project>/.lumi/mind-map`）。
    static let projectFolderName = "mind-map"

    /// 插件在 `kernel.storage` 中申请的 app 级目录名。
    static let appFolderName = "MindMap"

    static func configure(kernel: KernelLumi) {
        MindMapRuntime.kernel = kernel
        configure(appStorageDirectory: kernel.storage?.pluginDataDirectory(for: appFolderName))
        installProjectObserver(kernel: kernel)
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard MindMapRuntime.appStorageDirectory != resolved else { return }
        MindMapRuntime.appStorageDirectory = resolved
        MindMapStore.shared.setAppStorage(appStorageDirectory: resolved)
    }

    /// 安装对 `kernel.project` 变化的监听，自动刷新项目内存储路径。
    private static func installProjectObserver(kernel: KernelLumi) {
        projectCancellable = nil
        guard let project = kernel.project else {
            updateProjectStorageDirectory(projectPath: nil)
            return
        }
        currentProjectPath = project.currentProject?.path
        updateProjectStorageDirectory(projectPath: currentProjectPath)
        projectCancellable = project.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak project] _ in
                let newPath = project?.currentProject?.path
                guard newPath != currentProjectPath else { return }
                currentProjectPath = newPath
                updateProjectStorageDirectory(projectPath: newPath)
            }
    }

    private static func updateProjectStorageDirectory(projectPath: String?) {
        let resolved: URL?
        if let projectPath, !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = URL(fileURLWithPath: projectPath, isDirectory: true)
                .appendingPathComponent(".lumi", isDirectory: true)
                .appendingPathComponent(projectFolderName, isDirectory: true)
                .standardizedFileURL
        } else {
            resolved = nil
        }
        guard projectStorageDirectory != resolved else { return }
        projectStorageDirectory = resolved
        MindMapStore.shared.setProjectStorage(projectPath: projectPath, projectStorageDirectory: resolved)
    }

    /// 当前是否已打开项目（用于 LLM 工具默认 scope 选择）。
    static var hasOpenProject: Bool {
        guard let path = currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return false
        }
        return true
    }

    /// 当 LLM 工具没有显式传 scope 时，根据是否有打开项目返回默认 scope。
    static func defaultScope(hasOpenProject: Bool? = nil) -> MindMapScope {
        let opened = hasOpenProject ?? self.hasOpenProject
        return opened ? .project : .app
    }

    /// 测试辅助：重置所有运行时状态。
    static func reset() {
        projectCancellable = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
        kernel = nil
        MindMapStore.shared.setAppStorage(appStorageDirectory: nil)
        MindMapStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
