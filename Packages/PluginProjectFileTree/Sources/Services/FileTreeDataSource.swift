import Foundation
import SuperLogKit
import os

// MARK: - Protocols for Testability

/// 协议：文件系统读取能力。
/// 允许在测试中注入 mock 实现，避免依赖真实磁盘。
public protocol FileSystemReading: Sendable {
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey], options: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func isDirectory(_ url: URL) -> Bool
    func fileExists(atPath path: String) -> Bool
    func sortAndFilter(_ urls: [URL]) -> [URL]
}

/// 默认实现：委托给 FileManager + FileTreeFacade
public final class DefaultFileSystemReader: FileSystemReading {
    public init() {}

    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey], options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        // 不再使用 .skipsHiddenFiles，让隐藏文件（dotfiles）一并返回，类似 VSCode 文件树行为。
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)
    }

    public func isDirectory(_ url: URL) -> Bool {
        FileTreeFacade.isDirectory(url)
    }

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public func sortAndFilter(_ urls: [URL]) -> [URL] {
        FileTreeFacade.filterAndSortContents(urls)
    }
}

/// 协议：展开状态持久化能力。
public protocol ExpandedPathStoring: Sendable {
    func expandedPaths(for projectRoot: String) -> Set<String>
    func addExpandedPath(_ relativePath: String, for projectRoot: String)
    func removeExpandedPath(_ relativePath: String, for projectRoot: String)
}

/// 默认实现：委托给 FileTreeSettings.shared
public final class DefaultExpandedPathStore: ExpandedPathStoring {
    public init() {}
    
    public func expandedPaths(for projectRoot: String) -> Set<String> {
        FileTreeSettings.shared.expandedPaths(for: projectRoot)
    }
    
    public func addExpandedPath(_ relativePath: String, for projectRoot: String) {
        FileTreeSettings.shared.addExpandedPath(relativePath, for: projectRoot)
    }
    
    public func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        FileTreeSettings.shared.removeExpandedPath(relativePath, for: projectRoot)
    }
}

// MARK: - FileTreeDataSource

/// 文件树数据源
///
/// 负责将树形结构展平为线性列表，处理展开/折叠状态和精准刷新。
/// 同时管理文件节点和 Swift Package 依赖节点，统一输出为 `CollectionItem`。
@MainActor
final class FileTreeDataSource: SuperLog {
    nonisolated static let emoji = ""
    nonisolated static var verbose: Bool { ProjectFileTreePlugin.verbose }
    nonisolated static let logger = ProjectFileTreePlugin.logger

    /// 当前扁平化的节点列表（按可见顺序排列）
    private(set) var items: [CollectionItem] = []

    /// 仅文件系统节点（剔除软件包依赖区域），便于上层/测试按文件树结构进行判断。
    var fileItems: [FileTreeNodeItem] {
        items.compactMap { $0.fileItem }
    }

    /// 展开状态存储
    private let expandedPathStore: ExpandedPathStoring

    /// 文件系统读取器
    private let fileSystemReader: FileSystemReading

    /// 文件目录展开路径集合
    private var expandedPaths: Set<String> = []

    /// 项目根路径
    private(set) var projectRootPath: String = ""

    /// 当前缓存的软件包依赖列表
    private var cachedDependencies: [PackageDependency] = []

    /// 软件包依赖区域是否展开（按项目根路径缓存）
    private var isPackageExpanded: Bool = false

    /// 数据变化回调
    var onItemsChanged: (([CollectionItem]) -> Void)?

    /// 后台重建任务的版本号，用于丢弃过期的遍历结果（快速切换项目时）。
    private var rebuildGeneration: Int = 0

    /// 正在进行中的后台重建任务。
    private var rebuildTask: Task<Void, Never>?

    /// 使用默认依赖的初始化（保持向后兼容）
    init() {
        self.fileSystemReader = DefaultFileSystemReader()
        self.expandedPathStore = DefaultExpandedPathStore()
    }

    /// 可测试的初始化：注入依赖
    init(
        fileSystemReader: FileSystemReading,
        expandedPathStore: ExpandedPathStoring
    ) {
        self.fileSystemReader = fileSystemReader
        self.expandedPathStore = expandedPathStore
    }

    /// 设置项目根目录，重新构建节点列表
    func setProjectRoot(_ path: String) {
        projectRootPath = path
        expandedPaths = expandedPathStore.expandedPaths(for: path)
        isPackageExpanded = FileTreeSettings.shared.isPackageDependencySectionExpanded(for: path)
        // 切换项目时立即清空，避免短暂显示上一个项目的文件树残留。
        rebuildItems(clearImmediately: true)
    }

    /// 设置软件包依赖列表，追加到文件树末尾
    func setPackageDependencies(_ dependencies: [PackageDependency]) {
        cachedDependencies = dependencies
        appendPackageItems()
    }

    /// 切换软件包依赖区域的展开/折叠状态
    func togglePackageExpansion() {
        isPackageExpanded.toggle()
        FileTreeSettings.shared.setPackageDependencySectionExpanded(
            isPackageExpanded, for: projectRootPath
        )
        appendPackageItems()
    }

    /// 当前软件包依赖区域是否已展开
    var packageHeaderIsExpanded: Bool {
        isPackageExpanded
    }

    // MARK: - Internal

    /// 重建节点列表。
    ///
    /// 文件系统遍历（`expandDirectory`）是磁盘 I/O 密集型操作，在主线程同步执行会
    /// 阻塞 UI（尤其在大项目或深展开层级时）。这里将其下放到后台线程，主线程只负责
    /// 启动任务与最终回写结果。
    ///
    /// - Parameter clearImmediately: 为 true 时（如切换项目）立即清空并通知一次，
    ///   让视图先进入空态，避免短暂显示上一个项目的残留树；为 false 时（如展开/折叠、
    ///   手动刷新）保留旧列表直到新结果就绪，避免闪烁。
    private func rebuildItems(clearImmediately: Bool = false) {
        guard !projectRootPath.isEmpty else {
            rebuildTask?.cancel()
            items = []
            onItemsChanged?(items)
            return
        }

        if clearImmediately {
            items = []
            onItemsChanged?(items)
        }

        // 递增版本号，使任何在途的后台遍历结果作废。
        rebuildGeneration += 1
        let generation = rebuildGeneration

        // 快照重建所需的不可变输入（`fileSystemReader` 为 Sendable）。
        let rootURL = URL(fileURLWithPath: projectRootPath)
        let snapshotExpandedPaths = expandedPaths
        let snapshotProjectRootPath = projectRootPath
        let snapshotCachedDependencies = cachedDependencies
        let snapshotIsPackageExpanded = isPackageExpanded
        let reader = fileSystemReader

        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor [weak self] in
            // 磁盘遍历在后台线程执行。
            let fileItems = await Task.detached(priority: .userInitiated) {
                Self.expandDirectory(
                    rootURL, depth: 0,
                    projectRootPath: snapshotProjectRootPath,
                    expandedPaths: snapshotExpandedPaths,
                    fileSystemReader: reader
                )
            }.value

            guard let self, !Task.isCancelled, self.rebuildGeneration == generation else { return }

            let packageItems = Self.buildPackageItems(
                from: snapshotCachedDependencies,
                isPackageExpanded: snapshotIsPackageExpanded,
                projectRootPath: snapshotProjectRootPath
            )
            self.items = fileItems.map { .file($0) } + packageItems
            self.onItemsChanged?(self.items)
        }
    }

    /// 仅重建软件包依赖部分（不重新扫描文件系统）
    private func appendPackageItems() {
        // 保留已有的文件节点，只替换软件包部分
        let fileCount = items.firstIndex(where: {
            if case .packageHeader = $0 { return true }
            if case .packageDependency = $0 { return true }
            return false
        }) ?? items.count

        var newItems = Array(items.prefix(fileCount))
        newItems.append(contentsOf: Self.buildPackageItems(
            from: cachedDependencies,
            isPackageExpanded: isPackageExpanded,
            projectRootPath: projectRootPath
        ))
        items = newItems
        onItemsChanged?(items)
    }

    /// 根据当前依赖数据和展开状态，构建 PackageHeader + PackageDependency 节点
    private static func buildPackageItems(
        from dependencies: [PackageDependency],
        isPackageExpanded: Bool,
        projectRootPath: String
    ) -> [CollectionItem] {
        // 无依赖时不构建软件包区域（含表头），从 UI 上隐藏该功能。
        guard !dependencies.isEmpty else { return [] }

        let header = PackageHeaderItem(
            isExpanded: isPackageExpanded,
            dependencyCount: dependencies.count,
            projectRootPath: projectRootPath
        )
        var result: [CollectionItem] = [.packageHeader(header)]

        if isPackageExpanded {
            for dependency in dependencies {
                let node = PackageDependencyNodeItem(dependency: dependency)
                result.append(.packageDependency(node))
            }
        }
        return result
    }

    /// 递归展开目录，返回扁平化的可见节点列表
    ///
    /// `nonisolated`：仅依赖传入的快照值与 Sendable 的 `fileSystemReader`，
    /// 不触碰 `self` 的可变状态，因此可在后台线程执行磁盘遍历。
    private nonisolated static func expandDirectory(
        _ url: URL,
        depth: Int,
        projectRootPath: String,
        expandedPaths: Set<String>,
        fileSystemReader: FileSystemReading
    ) -> [FileTreeNodeItem] {
        var result: [FileTreeNodeItem] = []
        let relativePath = PathFormatter.expansionPath(for: url, projectRootPath: projectRootPath)
        // 根节点始终展开，避免文件树为空
        let isExpanded = depth == 0 ? true : expandedPaths.contains(relativePath)
        let isDirectory = fileSystemReader.isDirectory(url)

        result.append(FileTreeNodeItem(
            url: url, depth: depth, isDirectory: isDirectory,
            isExpanded: isExpanded, projectRootPath: projectRootPath,
            fileSystemReader: fileSystemReader
        ))

        if isDirectory && isExpanded {
            do {
                // 不再传 .skipsHiddenFiles，保持 VSCode 文件树行为：以点开头的隐藏文件也应展示。
                let children = try fileSystemReader.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                )
                let sorted = fileSystemReader.sortAndFilter(children)
                for childURL in sorted {
                    result.append(contentsOf: expandDirectory(
                        childURL, depth: depth + 1,
                        projectRootPath: projectRootPath,
                        expandedPaths: expandedPaths,
                        fileSystemReader: fileSystemReader
                    ))
                }
            } catch {
                Self.logger.warning("\(Self.t)无法展开目录 \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return result
    }

    /// 切换指定目录的展开状态
    func toggleExpansion(at url: URL) {
        guard let index = items.firstIndex(where: {
            if case .file(let fileItem) = $0 { return fileItem.url == url }
            return false
        }), case .file(let fileItem) = items[index], fileItem.isDirectory else { return }

        let relativePath = PathFormatter.expansionPath(for: url, projectRootPath: projectRootPath)

        if expandedPaths.contains(relativePath) {
            expandedPaths.remove(relativePath)
            expandedPathStore.removeExpandedPath(relativePath, for: projectRootPath)
            collapseChildren(of: url)
        } else {
            expandedPaths.insert(relativePath)
            expandedPathStore.addExpandedPath(relativePath, for: projectRootPath)
        }
        rebuildItems()
    }

    private func collapseChildren(of url: URL) {
        let urlPath = url.path
        expandedPaths = expandedPaths.filter { !$0.hasPrefix(urlPath) }
    }

    /// 精准刷新：仅重载指定目录的子节点
    func reloadDirectory(at url: URL) {
        // 找到对应的 file 节点
        guard let index = items.firstIndex(where: {
            if case .file(let fileItem) = $0 { return fileItem.url == url }
            return false
        }), case .file(let fileItem) = items[index] else { return }

        var endIndex = index + 1
        while endIndex < items.count {
            switch items[endIndex] {
            case .file(let f) where f.depth > fileItem.depth:
                endIndex += 1
            default:
                endIndex = items.count
            }
        }

        if fileItem.isExpanded {
            let newChildren = Self.expandDirectory(
                url, depth: fileItem.depth,
                projectRootPath: projectRootPath,
                expandedPaths: expandedPaths,
                fileSystemReader: fileSystemReader
            )
            let newItems: [CollectionItem] = newChildren.map { .file($0) }
            items.replaceSubrange(index..<endIndex, with: newItems)
        } else {
            let updatedItem = FileTreeNodeItem(
                url: url, depth: fileItem.depth, isDirectory: true,
                isExpanded: false, projectRootPath: projectRootPath,
                fileSystemReader: fileSystemReader
            )
            items[index] = .file(updatedItem)
        }
        onItemsChanged?(items)
    }

    /// 完全刷新
    func fullRefresh() {
        rebuildItems()
    }
}
