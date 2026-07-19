import Foundation
import SuperLogKit
import os
import FileSystemKit
import LibGit2Swift
import LumiKernel

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
/// 1. TreeView 持有 coordinator
/// 2. NodeView 展开/折叠时调用 coordinator 的 addExpandedPath / removeExpandedPath
/// 3. coordinator 自动更新 watcher 的监控列表
/// 4. 文件系统变化时 coordinator 递增刷新令牌并刷新 Git 状态
public final class RefreshCoordinator: ObservableObject, @unchecked Sendable, SuperLog {

    // MARK: - Properties

    public nonisolated static let emoji = "🌳"
    public nonisolated static let verbose: Bool = true

    /// 刷新令牌，每次变化时递增。SwiftUI 视图监听此值来触发重新加载。
    @Published public var refreshToken: Int = 0

    /// 精准刷新令牌：watcher 检测到具体目录变化时递增。
    /// 节点结合 `changedDirectoryPaths` 判断自身是否需要 reload，避免全树重载。
    @Published var targetedRefreshToken: Int = 0

    /// 最近一次精准刷新命中的目录绝对路径集合（标准化后）。
    /// 视图监听 `targetedRefreshToken` 变化后，比对此集合决定是否 reload。
    /// 空集合表示无具体目标（节点应跳过 reload）。
    @Published var changedDirectoryPaths: Set<String> = []

    /// 精准刷新路径集合的版本令牌：每次 `changedDirectoryPaths` 更新时递增。
    /// 用于 `NodeView.Equatable` 轻量比较（Int vs Set<String>），避免大集合 O(m) 比较。
    @Published var changedDirectoryPathsToken: Int = 0

    /// Git 状态快照，视图通过只读映射查询
    @Published public private(set) var gitStatusSnapshot: GitStatusSnapshot = .empty

    /// Git 状态令牌：每次 Git 状态更新时递增，用于驱动 Git 状态标记颜色更新，
    /// 但不触发文件列表重建。与文件系统的 targetedRefreshToken 分离。
    @Published var gitStatusToken: Int = 0

    /// 当前项目根路径
    private var projectRootPath: String = ""

    /// 当前已展开的目录相对路径集合
    private var expandedPaths: Set<String> = []

    /// 文件系统监听器（来自 FileTreeKit）
    private let watcher: FileTreeWatcher

    /// Git 状态提供器（线程安全，无 MainActor 依赖）
    private let gitStatusProvider = GitStatusProvider()

    /// Git 状态刷新任务
    private var gitStatusRefreshTask: Task<Void, Never>?

    /// Git 状态防抖任务
    private var gitStatusDebounceTask: Task<Void, Never>?
    
    /// Git 刷新请求计数器（用于日志去重）
    private var gitRefreshRequestCount: Int = 0

    /// 防抖任务
    private var debounceTask: Task<Void, Never>?

    /// 待下发的变化目录缓冲集合（标准化后的绝对路径）。
    /// watcher 事件累加进来，防抖结束后随 `targetedRefreshToken` 一起发布。
    private var pendingChangedPaths: Set<String> = []

    /// 是否正在进行防抖窗口等待（用于首帧即时策略）
    private var isDebouncePending: Bool = false

    /// 防抖间隔（纳秒）
    private let debounceInterval: UInt64 = 300_000_000 // 0.3 秒

    /// Git 状态防抖间隔（纳秒）
    private let gitStatusDebounceInterval: UInt64 = 500_000_000 // 0.5 秒

    /// 是否为 Git 仓库（缓存，避免每次都调用 LibGit2）
    private var isGitRepo: Bool = false

    public nonisolated static let logger = EditorFileTreePanelPlugin.logger

    // MARK: - Init

    public init() {
        let weakBox = WeakBox<RefreshCoordinator>()
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
        pendingChangedPaths.removeAll()
        isDebouncePending = false
        gitStatusRefreshTask?.cancel()
        gitStatusDebounceTask?.cancel()

        projectRootPath = path

        // 重置 Git 状态
        gitStatusSnapshot = .empty

        if !path.isEmpty {
            let store = FileTreeSettings.shared
            expandedPaths = store.expandedPaths(for: path)
            updateWatcher()

            // 检测是否为 Git 仓库并启动首次 Git 状态刷新
            isGitRepo = EditorFileTreePanelPlugin.gitStatusEnabled && GitAccessCoordinator.performSync { LibGit2.isGitRepository(at: path) }
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
        pendingChangedPaths.removeAll()
        isDebouncePending = false
        gitStatusRefreshTask?.cancel()
        gitStatusDebounceTask?.cancel()
    }

    // MARK: - Public - Expansion Tracking

    /// 添加一个已展开的目录（NodeView 展开时调用）
    public func addExpandedPath(_ relativePath: String) {
        guard !projectRootPath.isEmpty else { return }
        expandedPaths.insert(relativePath)
        updateWatcher()
    }

    /// 移除一个已折叠的目录（NodeView 折叠时调用）
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
        let store = FileTreeSettings.shared
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

        for manifestURL in PackageDependencyResolver.watchedManifestURLs(projectRootURL: rootURL) {
            let directoryURL = manifestURL.deletingLastPathComponent().standardizedFileURL
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue {
                directoryURLs.insert(directoryURL)
            }
        }

        // 监控 .git 元数据目录：git commit/reset、分支切换（写 HEAD/refs/heads）、
        // merge/rebase（写 MERGE_HEAD、rebase-merge/）等操作可能只改 .git 内部而不触动工作区，
        // 必须主动监听才能让文件树的 Git 状态标记及时刷新。
        for gitDir in Self.gitMetadataWatchURLs(projectRootURL: rootURL) {
            directoryURLs.insert(gitDir)
        }

        watcher.updateWatchedDirectories(directoryURLs)

        if Self.verbose {
            Self.logger.info("\(Self.t)📡 已更新监控列表：\(directoryURLs.count) 个目录")
        }
    }

    /// 需要监听的 `.git` 内部目录集合。
    ///
    /// - `.git/refs`：捕获 refs/heads（分支切换）、refs/tags 等引用变更
    /// 
    /// 不监听整个 `.git` 目录，避免 `.git/objects/` 频繁写入导致无效刷新。
    /// 只监听真正影响 Git 状态的关键位置。
    /// 仅返回实际存在的目录，避免对非 Git 仓库空跑。
    static func gitMetadataWatchURLs(projectRootURL: URL) -> [URL] {
        let gitURL = projectRootURL.appendingPathComponent(".git").standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gitURL.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        
        var urls: [URL] = []
        
        // 只监听 refs 目录（分支切换、tag 变更）
        let refsURL = gitURL.appendingPathComponent("refs").standardizedFileURL
        var refsIsDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: refsURL.path, isDirectory: &refsIsDir), refsIsDir.boolValue {
            urls.append(refsURL)
        }
        
        // 可选：监听 logs/refs 目录（reflog 变更）
        let logsRefsURL = gitURL.appendingPathComponent("logs/refs").standardizedFileURL
        var logsIsDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: logsRefsURL.path, isDirectory: &logsIsDir), logsIsDir.boolValue {
            urls.append(logsRefsURL)
        }
        
        return urls
    }

    /// 处理目录变化事件
    private func handleDirectoryChanged(url: URL) {
        // .git 内部变化只影响 Git 状态标记，不应触发文件树内容重载（否则会把 .git
        // 当成普通变更目录下发，导致节点无谓地重新加载子项）。
        let normalizedPath = PathFormatter.normalizedFilePath(url)
        let isGitMetadataChange = normalizedPath.contains("/.git")

        if isGitMetadataChange {
            // 仅刷新 Git 状态（日志由 scheduleGitStatusRefresh 统一管理）
            scheduleGitStatusRefresh()
        } else {
            if Self.verbose {
                Self.logger.info("\(Self.t)🔄 检测到目录变化：\(url.lastPathComponent)")
            }
            // 收集变化目录的标准化路径，随精准刷新下发，避免全树重载
            pendingChangedPaths.insert(normalizedPath)
            triggerTargetedRefresh()
            scheduleGitStatusRefresh()
        }
    }

    /// 全量防抖刷新：短时间内多次变化合并为一次，驱动整棵树重新加载。
    /// 用于手动刷新、项目切换、文件树内部增删改等需要触及全部节点的场景。
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

    /// 精准刷新策略：首帧即时 + 后续合并
    ///
    /// 工作原理：
    /// 1. 当第一个 FS 事件到来时（isDebouncePending == false），立即发布当前 pendingChangedPaths 并递增 targetedRefreshToken
    /// 2. 设置 isDebouncePending = true，启动 trailing debounce 计时器
    /// 3. 在 debounce 窗口期间，后续事件继续累积到 pendingChangedPaths
    /// 4. 当 debounce 窗口结束（无新事件），发布累积的 paths 并重置状态
    ///
    /// 优势：首帧立即响应，用户感知延迟从 300ms 降到 0ms；后续事件仍然合并，避免频繁刷新
    private func triggerTargetedRefresh() {
        Task { @MainActor in
            if !self.isDebouncePending {
                // 首帧即时：立即发布当前变更
                self.isDebouncePending = true
                self.publishTargetedRefresh()
                // 启动 trailing debounce 窗口
                self.startTrailingDebounce()
            } else {
                // 后续事件：继续累积到 pendingChangedPaths，等待 debounce 窗口结束
                if Self.verbose {
                    Self.logger.info("\(Self.t)⏳ 精准刷新防抖中，累积变更路径：\(self.pendingChangedPaths.count) 个")
                }
            }
        }
    }

    /// 发布精准刷新：将 pendingChangedPaths 发布到 changedDirectoryPaths 并递增 targetedRefreshToken
    private func publishTargetedRefresh() {
        guard !pendingChangedPaths.isEmpty else {
            isDebouncePending = false
            return
        }
        changedDirectoryPaths = pendingChangedPaths
        changedDirectoryPathsToken += 1
        pendingChangedPaths.removeAll()
        targetedRefreshToken += 1
        if Self.verbose {
            Self.logger.info("\(Self.t)🎯 精准刷新：\(self.changedDirectoryPaths.count) 个目录，令牌：\(self.targetedRefreshToken)")
        }
    }

    /// 启动 trailing debounce 计时器：等待 debounceInterval 后发布累积的变更
    private func startTrailingDebounce() {
        debounceTask?.cancel()
        let interval = self.debounceInterval
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard let self else { return }
            // 窗口结束：发布累积的变更并重置状态
            self.publishTargetedRefresh()
            self.isDebouncePending = false
            if Self.verbose {
                Self.logger.info("\(Self.t)✅ 精准刷新防抖窗口结束")
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
            // 递增 gitStatusToken 驱动 Git 状态标记颜色更新，但不触发文件列表重建
            self.gitStatusToken += 1
        }
    }

    /// 防抖刷新 Git 状态（用于文件系统变化后的增量刷新）
    private func scheduleGitStatusRefresh() {
        guard isGitRepo else { return }

        gitRefreshRequestCount += 1
        let currentCount = gitRefreshRequestCount
        
        // 首次请求时记录日志
        if currentCount == 1 {
            if Self.verbose {
                Self.logger.info("\(Self.t)🔄 检测到 .git 变化，准备刷新状态")
            }
        }

        gitStatusDebounceTask?.cancel()
        let interval = self.gitStatusDebounceInterval
        gitStatusDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard let self else { return }
            
            // 防抖结束时，如果有多次请求，记录合并信息
            if currentCount < self.gitRefreshRequestCount, Self.verbose {
                Self.logger.info("\(Self.t)🔀 合并了 \(self.gitRefreshRequestCount - currentCount + 1) 次 Git 变化")
            }
            
            // 重置计数器
            self.gitRefreshRequestCount = 0
            self.refreshGitStatus()
        }
    }
}
