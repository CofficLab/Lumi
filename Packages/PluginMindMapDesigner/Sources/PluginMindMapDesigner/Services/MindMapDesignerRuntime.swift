import Foundation
import KernelCore
import ProviderProject

/// 思维导图只存储在当前项目目录中。
public enum MindMapScope: String, CaseIterable, Sendable {
    case project

    func displayName() -> String {
        MindMapLocalization.string("In Project")
    }
}

/// 思维导图运行时：绑定当前项目的 `.lumi/mind-map` 目录，并监听项目变化。
@MainActor
enum MindMapDesignerRuntime {
    /// 项目内存储目录（基于当前打开项目，nil 表示无打开项目）。
    static private(set) var projectStorageDirectory: URL?

    /// 当前打开项目的路径（供工具访问与 UI 展示）。
    static private(set) var currentProjectPath: String?

    /// 项目内存储目录的末段名称（`<project>/.lumi/mind-map`）。
    static let projectFolderName = "mind-map"

    static func configure(kernel: KernelCoreContainer) {
        updateProjectStorageDirectory(
            projectPath: kernel.resolveProvider((any ProjectProviding).self)?.currentProject?.path
        )
    }

    /// Called by the plugin-owned project observer when the active project changes.
    static func updateProjectStorageDirectory(projectPath: String?) {
        guard projectPath != currentProjectPath else { return }
        currentProjectPath = projectPath
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

    /// 当前是否已打开项目。
    static var hasOpenProject: Bool {
        guard let path = currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return false
        }
        return true
    }

    /// 保留统一设计器接口，所有思维导图均固定使用项目作用域。
    static func defaultScope(hasOpenProject: Bool? = nil) -> MindMapScope {
        .project
    }

    /// 测试辅助：手动注入项目路径与项目内存储目录。
    static func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        currentProjectPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = projectStorageDirectory?.standardizedFileURL
        guard self.projectStorageDirectory != resolved else { return }
        self.projectStorageDirectory = resolved
        MindMapStore.shared.setProjectStorage(projectPath: currentProjectPath, projectStorageDirectory: resolved)
    }

    /// 测试辅助：重置所有运行时状态。
    static func reset() {
        projectStorageDirectory = nil
        currentProjectPath = nil
        MindMapStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
