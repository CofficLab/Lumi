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

    /// 按对话项目隔离的 store 实例（key = 项目路径）。
    ///
    /// `MindMapStore.shared` 跟随 UI「当前打开的项目」。对话 A 的工具调用
    /// 若在用户切到对话 B 之后才执行，用 shared 就会写进 B 的项目。
    /// 因此对话项目与 UI 当前项目不同时，改用按对话项目目录配置的独立实例，
    /// 它的内存列表与落盘路径都只属于该对话的项目。
    private static var scopedStores: [String: MindMapStore] = [:]

    /// 指定项目路径对应的存储目录（`<项目>/.lumi/mind-map`）。
    ///
    /// 纯函数：不依赖 UI 当前打开的项目，供工具按「调用所属对话的项目」解析路径。
    static func mindMapStorageDirectory(forProjectPath projectPath: String?) -> URL? {
        guard let path = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(projectFolderName, isDirectory: true)
            .standardizedFileURL
    }

    /// 标准化项目路径（两端统一后比较，避免尾斜杠等差异）。
    private static func standardizedPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }

    /// 取某个项目对应的 store：与 UI 当前项目一致时复用 shared，
    /// 否则返回按该项目目录配置的隔离实例。
    static func store(forProjectPath projectPath: String?) -> MindMapStore {
        guard let normalized = standardizedPath(projectPath) else {
            return MindMapStore.shared
        }
        // 与 UI 当前打开的项目一致：直接用 shared，画布可实时看到 Agent 的改动。
        if normalized == standardizedPath(MindMapStore.shared.currentProjectPath) {
            return MindMapStore.shared
        }
        if let cached = scopedStores[normalized] {
            return cached
        }
        let store = MindMapStore()
        store.setProjectStorage(
            projectPath: normalized,
            projectStorageDirectory: mindMapStorageDirectory(forProjectPath: normalized)
        )
        scopedStores[normalized] = store
        return store
    }

    static func configure(kernel: KernelCoreContainer) {
        updateProjectStorageDirectory(
            projectPath: kernel.resolveProvider((any ProjectProviding).self)?.currentProject?.path
        )
    }

    /// Called by the plugin-owned project observer when the active project changes.
    static func updateProjectStorageDirectory(projectPath: String?) {
        guard projectPath != currentProjectPath else { return }
        currentProjectPath = projectPath
        let resolved = mindMapStorageDirectory(forProjectPath: projectPath)
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
        scopedStores.removeAll()
        MindMapStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
