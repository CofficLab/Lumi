import Foundation
import FileSystemKit
import LumiCoreKit

/// Editor Rail 文件树本地存储
///
/// 负责持久化文件树的展开状态和最近项目路径。
/// 存储位置沿用旧目录：<dataRoot>/AgentEditorFileTree/settings.plist
///
/// 作为 FileTreeKit.FileTreeStore 的单例包装器，
/// 通过 currentLumiCore 注入存储目录。
public final class FileTreeSettings: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = FileTreeSettings()

    // MARK: - Properties

    private let store: FileTreeStore

    // MARK: - Initialization

    private init() {
        let root = (EditorFileTreeV2PluginRuntimeBridge.dataRootDirectory
            ?? EditorFileTreeV2PluginRuntimeBridge.fallbackRootDirectory)
            .appendingPathComponent("AgentEditorFileTree", isDirectory: true)
        self.store = FileTreeStore(directory: root)
    }

    // MARK: - Expanded Paths

    /// 获取已展开的文件夹相对路径集合
    public func expandedPaths(for projectRoot: String) -> Set<String> {
        store.expandedPaths(for: projectRoot)
    }

    /// 保存已展开的文件夹相对路径集合
    @discardableResult
    public func setExpandedPaths(_ paths: Set<String>, for projectRoot: String) -> Bool {
        store.setExpandedPaths(paths, for: projectRoot)
    }

    /// 添加一个展开的文件夹路径
    @discardableResult
    public func addExpandedPath(_ relativePath: String, for projectRoot: String) -> Bool {
        store.addExpandedPath(relativePath, for: projectRoot)
    }

    /// 移除一个折叠的文件夹路径
    @discardableResult
    public func removeExpandedPath(_ relativePath: String, for projectRoot: String) -> Bool {
        store.removeExpandedPath(relativePath, for: projectRoot)
    }

    // MARK: - Package Dependencies

    public func isPackageDependencySectionExpanded(for projectRoot: String) -> Bool {
        UserDefaults.standard.object(forKey: packageSectionExpandedKey(projectRoot)) as? Bool ?? true
    }

    public func setPackageDependencySectionExpanded(_ isExpanded: Bool, for projectRoot: String) {
        UserDefaults.standard.set(isExpanded, forKey: packageSectionExpandedKey(projectRoot))
    }

    /// 记录上次打开的项目路径
    @discardableResult
    public func setLastProjectPath(_ path: String) -> Bool {
        store.setLastProjectPath(path)
    }

    /// 获取上次打开的项目路径
    public func lastProjectPath() -> String? {
        store.lastProjectPath()
    }

    private func packageSectionExpandedKey(_ projectRoot: String) -> String {
        "EditorRailFileTree.packageDependencies.expanded.\(projectRoot)"
    }
}