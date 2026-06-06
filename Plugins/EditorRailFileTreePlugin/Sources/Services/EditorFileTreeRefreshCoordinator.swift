import Foundation
import SuperLogKit
import os
import FileTreeKit
import LibGit2Swift

/// 弱引用盒子，用于解决 init 中闭包捕获 self 的顺序问题
private final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    public init(_ value: T? = nil) { self.value = value }
}

/// Editor Rail 文件树刷新协调器
///
/// 作为 FileTreeKit.FileTreeWatcher 和 SwiftUI 视图之间的桥梁：
/// - 接收 watcher 的文件系统变化通知
/// - 跟踪当前已展开的目录列表
/// - 合并短时间内的文件系统事件
/// - 通过刷新令牌驱动 SwiftUI 视图重新加载数据
/// - 管理文件树 Git 状态快照
///
/// 使用方式：
/// 1. EditorFileTreeView 持有 coordinator
/// 2. EditorFileTreeNodeView 展开/折叠时调用 coordinator 的 addExpandedPath / removeExpandedPath
/// 3. coordinator 自动更新 watcher 的监控列表
/// 4. 文件系统变化时 coordinator 递增刷新令牌并刷新 Git 状态
public final class EditorFileTreeRefreshCoordinator: ObservableObject, @unchecked Sendable, SuperLog {

    // MARK: - Properties

    public nonisolated static let emoji = "🌳"
    public nonisolated static let verbose: Bool = false

    /// 刷新令牌，每次变化时递增。SwiftUI 视图监听此值来触发重新加载。
    @Published var refreshToken: Int = 0

    /// Git 状态快照，视图通过只读映射查询
    @Published var gitStatusSnapshot: EditorFileTreeGitStatusSnapshot = .empty

    /// 当前项目根路径
    private var projectRootPath: String = ""

    /// 当前已展开的目录相对路径集合
    private var expandedPaths: Set<String> = []

    /// 文件系统监听器（来自 FileTreeKit）
    private let watcher: FileTreeWatcher

    /// Git 状态提供器（线程安全，无 MainActor 依赖）
    private let gitStatusProvider = EditorFileTreeGitStatusProvider()

    /// Git 状态刷新任务
    private var gitStatusRefreshTask: Task<Void, Never>?

    /// Git 状态防抖任务
    private var gitStatusDebounceTask: Task<Void, Never>?

    /// 防抖任务
    private var debounceTask: Task<Void, Never>?

    /// 防抖间隔（纳秒）
    private let debounceInterval: UInt64 = 300_000_000 // 0.3 秒

    /// Git 状态防抖间隔（纳秒）
    private let gitStatusDebounceInterval: UInt64 = 200_000_000 // 0.2 秒

    /// 是否为 Git 仓库（缓存，避免每次都调用 LibGit2）
    private var isGitRepo: Bool = false

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.coordinator")

    // MARK: - Init

    public init() {
        let weakBox = WeakBox<EditorFileTreeRefreshCoordinator>()
        watcher = FileTreeWatcher { changedURL in
            weakBox.value?.handleDirectoryChanged(url: changedURL)
        }
        weakBox.value = self
    }

    deinit {
        watcher.stopAll()
        gitStatusRefreshTask?.cancel()
        gitStatusDebounceTask?.cancel()
    }

    // MARK: - Public - Lifecycle

    /// 设置当前项目根路径（项目切换时调用）
    public func setProjectRootPath(_ path: String) {
        guard path != projectRootPath else { return }

        // 清理旧项目的状态
        watcher.stopAll()
        expandedPaths.removeAll()
        gitStatusRefreshTask?.cancel()
        gitStatusDebounceTask?.cancel()

        projectRootPath = path

        // 重置 Git 状态
        gitStatusSnapshot = .empty

        if !path.isEmpty {
            let store = EditorFileTreeStore.shared
            expandedPaths = store.expandedPaths(for: path)
            updateWatcher()

            // 检测是否为 Git 仓库并启动首次 Git 状态刷新
            isGitRepo = LibGit2.isGitRepository(at: path)
            if isGitRepo {
                refreshGitStatus()
            }
        } else {
            isGitRepo = false
        }
    }

    /// 停止所有监听（视图消失时调用）
    public func stop() {
        watcher.stopAll()
        debounceTask?.cancel()
        gitStatusRefreshTask?.cancel()
        gitStatusDebounceTask?.cancel()
    }

    // MARK: - Public - Expansion Tracking

    /// 添加一个已展开的目录（EditorFileTreeNodeView 展开时调用）
    public func addExpandedPath(_ relativePath: String) {
        guard !projectRootPath.isEmpty else { return }
        expandedPaths.insert(relativePath)
        updateWatcher()
    }

    /// 移除一个已折叠的目录（EditorFileTreeNodeView 折叠时调用）
    public func removeExpandedPath(_ relativePath: String) {
        guard !projectRootPath.isEmpty else { return }
        expandedPaths.remove(relativePath)
        // 同时移除其子目录（它们也不再可见）
        let prefix = relativePath + "/"
        expandedPaths = expandedPaths.filter { !$0.hasPrefix(prefix) }
        updateWatcher()
    }

    /// 从 store 同步展开状态（用于初始化恢复）
    public func syncExpandedPathsFromStore() {
        guard !projectRootPath.isEmpty else { return }
        let store = EditorFileTreeStore.shared
        expandedPaths = store.expandedPaths(for: projectRootPath)
        updateWatcher()
    }

    // MARK: - Public - Manual Refresh

    /// 手动触发一次刷新
    public func refresh() {
        triggerRefresh()
    }

    // MARK: - Private - File System Watcher

    /// 将已展开的相对路径列表转换为绝对 URL 并更新 watcher
    private func updateWatcher() {
        guard !projectRootPath.isEmpty else {
            watcher.stopAll()
            return
        }

        var directoryURLs: Set<URL> = []
        let rootURL = URL(fileURLWithPath: projectRootPath).standardizedFileURL

        // 始终监控根目录
        directoryURLs.insert(rootURL)

        // 监控所有已展开的目录
        for relativePath in expandedPaths {
            let fullPath: String
            if relativePath.isEmpty || relativePath == "/" {
                fullPath = projectRootPath
            } else if relativePath.hasPrefix("/") {
                fullPath = projectRootPath + relativePath
            } else {
                fullPath = projectRootPath + "/" + relativePath
            }
            let url = URL(fileURLWithPath: fullPath).standardizedFileURL

            // 确保路径存在且确实是目录
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                directoryURLs.insert(url)
            }
        }

        for manifestURL in EditorPackageDependencyResolver.watchedManifestURLs(projectRootURL: rootURL) {
            let directoryURL = manifestURL.deletingLastPathComponent().standardizedFileURL
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue {
                directoryURLs.insert(directoryURL)
            }
        }

        watcher.updateWatchedDirectories(directoryURLs)

        if Self.verbose {
            Self.logger.info("\(Self.t)📡 已更新监控列表：\(directoryURLs.count) 个目录")
        }
    }

    /// 处理目录变化事件
    private func handleDirectoryChanged(url: URL) {
        if Self.verbose {
            Self.logger.info("\(Self.t)🔄 检测到目录变化：\(url.lastPathComponent)")
        }
        triggerRefresh()
        scheduleGitStatusRefresh()
    }

    /// 防抖刷新：短时间内多次变化合并为一次
    private func triggerRefresh() {
        debounceTask?.cancel()
        let interval = self.debounceInterval
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard let self else { return }
            self.refreshToken += 1
            if Self.verbose {
                Self.logger.info("\(Self.t)✅ 刷新令牌递增：\(self.refreshToken)")
            }
        }
    }

    // MARK: - Private - Git Status Refresh

    /// 立即刷新 Git 状态（用于项目切换后的首次加载）
    private func refreshGitStatus() {
        let path = projectRootPath
        guard !path.isEmpty, isGitRepo else { return }

        gitStatusRefreshTask?.cancel()
        gitStatusRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let snapshot = await Task.detached(priority: .utility) { [provider = self.gitStatusProvider] in
                provider.captureSnapshot(projectRootPath: path)
            }.value

            guard let snapshot, !Task.isCancelled else { return }

            // 校验结果仍属于当前项目
            guard self.projectRootPath == path else { return }

            self.gitStatusSnapshot = snapshot
        }
    }

    /// 防抖刷新 Git 状态（用于文件系统变化后的增量刷新）
    private func scheduleGitStatusRefresh() {
        guard isGitRepo else { return }

        gitStatusDebounceTask?.cancel()
        let interval = self.gitStatusDebounceInterval
        gitStatusDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard let self else { return }
            self.refreshGitStatus()
        }
    }
}
