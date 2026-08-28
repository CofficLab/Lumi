import Combine
import Foundation
import KernelCore
import ProviderProject
import ProviderStorage

/// 思维导图存储作用域：当前项目目录或应用级数据目录。
public enum MindMapScope: String, CaseIterable, Sendable {
    case project
    case app

    var rawName: String { rawValue }

    func displayName() -> String {
        switch self {
        case .project: MindMapLocalization.string("In Project")
        case .app: MindMapLocalization.string("In App")
        }
    }
}

/// 思维导图运行时（KernelCore 版本）：在 `onBoot` 时绑定存储目录，并监听项目变化以刷新项目作用域。
///
/// 复刻自旧版 `MindMapRuntime`（KernelLumi），差异：
/// - `kernel.storage` / `kernel.project` → `kernel.resolveProvider((any StorageProviding).self)` /
///   `kernel.resolveProvider((any ProjectProviding).self)`
/// - app 级目录由 `StorageProviding.pluginDataDirectory(for: pluginID)` 提供（按插件 id 隔离）
@MainActor
enum MindMapDesignerRuntime {
    /// APP 内存储目录（应用级别，跨项目共享）。
    static private(set) var appStorageDirectory: URL?

    /// 项目内存储目录（基于当前打开项目，nil 表示无打开项目）。
    static private(set) var projectStorageDirectory: URL?

    /// 当前打开项目的路径（供工具访问与 UI 展示）。
    static private(set) var currentProjectPath: String?

    private static var projectCancellable: AnyCancellable?

    /// 项目内存储目录的末段名称（`<project>/.lumi/mind-map`）。
    static let projectFolderName = "mind-map"

    static func configure(kernel: KernelCoreContainer, pluginID: String) {
        let appDirectory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: pluginID)
        configure(appStorageDirectory: appDirectory)
        installProjectObserver(kernel: kernel)
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard self.appStorageDirectory != resolved else { return }
        self.appStorageDirectory = resolved
        MindMapStore.shared.setAppStorage(appStorageDirectory: resolved)
    }

    /// 安装对 `ProjectProviding` 变化的监听，自动刷新项目内存储路径。
    private static func installProjectObserver(kernel: KernelCoreContainer) {
        projectCancellable = nil
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            currentProjectPath = nil
            updateProjectStorageDirectory(projectPath: nil)
            return
        }

        currentProjectPath = project.currentProject?.path
        updateProjectStorageDirectory(projectPath: currentProjectPath)
        projectCancellable = project.objectWillChange
            .sink { [weak project] _ in
                Task { @MainActor in
                    let newPath = project?.currentProject?.path
                    guard newPath != currentProjectPath else { return }
                    currentProjectPath = newPath
                    updateProjectStorageDirectory(projectPath: newPath)
                }
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
        (hasOpenProject ?? self.hasOpenProject) ? .project : .app
    }

    /// 测试辅助：手动注入项目路径与项目内存储目录。
    static func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        currentProjectPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = projectStorageDirectory?.standardizedFileURL
        guard self.projectStorageDirectory != resolved else { return }
        self.projectStorageDirectory = resolved
        MindMapStore.shared.setProjectStorage(projectPath: currentProjectPath, projectStorageDirectory: resolved)
    }

    /// 测试辅助：重置所有运行时状态（含 app / project 路径及订阅）。
    static func reset() {
        projectCancellable = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
        MindMapStore.shared.setAppStorage(appStorageDirectory: nil)
        MindMapStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
