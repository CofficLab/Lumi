import Combine
import Foundation
import KernelLumi

/// 存储作用域：APP 内（应用数据目录）vs 项目内（当前项目 `.lumi` 目录）。
public enum IconScope: String, CaseIterable, Sendable {
    case project
    case app

    /// LLM 工具参数使用的字符串名。
    var rawName: String { rawValue }

    /// UI 显示名（根据本地化）。
    func displayName() -> String {
        switch self {
        case .project: AppIconDesignerLocalization.string("In Project")
        case .app: AppIconDesignerLocalization.string("In App")
        }
    }
}

@MainActor
enum IconDesignerRuntime {
    /// APP 内存储目录（应用级别，跨项目共享）。
    static private(set) var appStorageDirectory: URL?

    /// 项目内存储目录（基于当前打开项目，nil 表示无打开项目）。
    static private(set) var projectStorageDirectory: URL?

    /// 当前打开项目的路径（供工具访问与 UI 展示）。
    static private(set) var currentProjectPath: String?

    /// 内核实例（在 `onBoot` 时注入）。
    static private(set) var kernel: KernelLumi?

    private static var projectCancellable: AnyCancellable?

    /// 项目内存储目录的末段名称（`<project>/.lumi/app-icon-designer`）。
    static let projectFolderName = "app-icon-designer"

    static func configure(kernel: KernelLumi) {
        IconDesignerRuntime.kernel = kernel
        configure(appStorageDirectory: kernel.storage?.pluginDataDirectory(for: "AppIconDesigner"))
        installProjectObserver(kernel: kernel)
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard IconDesignerRuntime.appStorageDirectory != resolved else { return }
        IconDesignerRuntime.appStorageDirectory = resolved
        IconDocumentStore.shared.setAppStorage(appStorageDirectory: resolved)
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
        IconDocumentStore.shared.setProjectStorage(projectPath: projectPath, projectStorageDirectory: resolved)
    }

    /// 当前是否已打开项目（用于 LLM 工具默认 scope 选择）。
    static var hasOpenProject: Bool {
        guard let path = currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return false
        }
        return true
    }

    /// 测试辅助：手动注入项目路径与项目内存储目录。
    static func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        currentProjectPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = projectStorageDirectory?.standardizedFileURL
        let normalizedPath = currentProjectPath?.isEmpty == false ? currentProjectPath : nil
        guard self.projectStorageDirectory != resolved || self.currentProjectPath != normalizedPath else { return }
        self.projectStorageDirectory = resolved
        IconDocumentStore.shared.setProjectStorage(projectPath: normalizedPath, projectStorageDirectory: resolved)
    }

    /// 测试辅助：手动注入 APP 内存储目录。
    static func setAppStorage(_ directory: URL?) {
        configure(appStorageDirectory: directory)
    }

    /// 测试辅助：重置所有运行时状态（含 app / project 路径及订阅）。
    static func reset() {
        projectCancellable = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
        kernel = nil
        IconDocumentStore.shared.setAppStorage(appStorageDirectory: nil)
        IconDocumentStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }

    /// 当 LLM 工具没有显式传 scope 时，根据是否有打开项目返回默认 scope。
    static func defaultScope(hasOpenProject: Bool? = nil) -> IconScope {
        let opened = hasOpenProject ?? self.hasOpenProject
        return opened ? .project : .app
    }
}
