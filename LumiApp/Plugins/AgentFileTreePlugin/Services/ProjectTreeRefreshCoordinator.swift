import Foundation
import os

/// 弱引用盒子，用于解决 init 中闭包捕获 self 的顺序问题
private final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T? = nil) { self.value = value }
}

/// 文件树刷新协调器
///
/// 作为 ProjectTreeWatcher 和 SwiftUI 视图之间的桥梁：
/// - 接收 watcher 的文件系统变化通知
/// - 跟踪当前已展开的目录列表
/// - 通过刷新令牌驱动 SwiftUI 视图重新加载数据
///
/// 使用方式：
/// 1. ProjectTreeView 持有 coordinator
/// 2. FileNodeView 展开/折叠时调用 coordinator 的 addExpandedPath / removeExpandedPath
/// 3. coordinator 自动更新 watcher 的监控列表
/// 4. 文件系统变化时 coordinator 递增刷新令牌
final class ProjectTreeRefreshCoordinator: ObservableObject, @unchecked Sendable {

    // MARK: - Properties

    /// 刷新令牌，每次变化时递增。SwiftUI 视图监听此值来触发重新加载。
    @Published var refreshToken: Int = 0

    /// 当前项目根路径
    private var projectRootPath: String = ""

    /// 当前已展开的目录相对路径集合
    private var expandedPaths: Set<String> = []

    /// 文件系统监听器
    private let watcher: ProjectTreeWatcher

    /// 防抖任务
    private var debounceTask: Task<Void, Never>?

    /// 防抖间隔（纳秒）
    private let debounceInterval: UInt64 = 300_000_000 // 0.3 秒

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.coordinator")

    // MARK: - Init

    init() {
        let weakBox = WeakBox<ProjectTreeRefreshCoordinator>()
        watcher = ProjectTreeWatcher { changedURL in
            weakBox.value?.handleDirectoryChanged(url: changedURL)
        }
        weakBox.value = self
    }

    deinit {
        watcher.stopAll()
    }

    // MARK: - Public - Lifecycle

    /// 设置当前项目根路径（项目切换时调用）
    func setProjectRootPath(_ path: String) {
        guard path != projectRootPath else { return }

        // 清理旧项目的状态
        watcher.stopAll()
        expandedPaths.removeAll()

        projectRootPath = path

        // 从 store 恢复展开状态
        if !path.isEmpty {
            let store = AgentFileTreePluginLocalStore.shared
            expandedPaths = store.expandedPaths(for: path)
            updateWatcher()
        }
    }

    /// 停止所有监听（视图消失时调用）
    func stop() {
        watcher.stopAll()
        debounceTask?.cancel()
    }

    // MARK: - Public - Expansion Tracking

    /// 添加一个已展开的目录（FileNodeView 展开时调用）
    func addExpandedPath(_ relativePath: String) {
        guard !projectRootPath.isEmpty else { return }
        expandedPaths.insert(relativePath)
        updateWatcher()
    }

    /// 移除一个已折叠的目录（FileNodeView 折叠时调用）
    func removeExpandedPath(_ relativePath: String) {
        guard !projectRootPath.isEmpty else { return }
        expandedPaths.remove(relativePath)
        // 同时移除其子目录（它们也不再可见）
        let prefix = relativePath + "/"
        expandedPaths = expandedPaths.filter { !$0.hasPrefix(prefix) }
        updateWatcher()
    }

    /// 从 store 同步展开状态（用于初始化恢复）
    func syncExpandedPathsFromStore() {
        guard !projectRootPath.isEmpty else { return }
        let store = AgentFileTreePluginLocalStore.shared
        expandedPaths = store.expandedPaths(for: projectRootPath)
        updateWatcher()
    }

    // MARK: - Public - Manual Refresh

    /// 手动触发一次刷新
    func refresh() {
        triggerRefresh()
    }

    // MARK: - Private

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

        watcher.updateWatchedDirectories(directoryURLs)

        Self.logger.info("📡 已更新监控列表：\(directoryURLs.count) 个目录")
    }

    /// 处理目录变化事件
    private func handleDirectoryChanged(url: URL) {
        Self.logger.info("🔄 检测到目录变化：\(url.lastPathComponent)")
        triggerRefresh()
    }

    /// 防抖刷新：短时间内多次变化合并为一次
    private func triggerRefresh() {
        debounceTask?.cancel()
        let interval = self.debounceInterval
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard let self else { return }
            self.refreshToken += 1
            Self.logger.info("✅ 刷新令牌递增：\(self.refreshToken)")
        }
    }
}
