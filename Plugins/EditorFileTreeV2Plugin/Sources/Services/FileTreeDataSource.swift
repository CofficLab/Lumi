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

/// 文件树数据源
///
/// 负责将树形结构展平为线性列表，处理展开/折叠状态和精准刷新。
@MainActor
final class FileTreeDataSource: SuperLog {
    nonisolated static let emoji = ""
    nonisolated static var verbose: Bool { EditorFileTreeV2Plugin.verbose }
    nonisolated static let logger = EditorFileTreeV2Plugin.logger

    /// 当前扁平化的节点列表（按可见顺序排列）
    private(set) var items: [FileTreeNodeItem] = []
    
    /// 展开状态存储
    private let expandedPathStore: ExpandedPathStoring
    
    /// 文件系统读取器
    private let fileSystemReader: FileSystemReading
    
    /// 展开状态存储（与现有 FileTreeSettings 兼容）
    private var expandedPaths: Set<String> = []
    
    /// 项目根路径
    private(set) var projectRootPath: String = ""
    
    /// 数据变化回调
    var onItemsChanged: (([FileTreeNodeItem]) -> Void)?
    
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
        rebuildItems()
    }
    
    private func rebuildItems() {
        guard !projectRootPath.isEmpty else {
            items = []
            onItemsChanged?(items)
            return
        }
        let rootURL = URL(fileURLWithPath: projectRootPath)
        items = expandDirectory(rootURL, depth: 0)
        onItemsChanged?(items)
    }
    
    /// 递归展开目录，返回扁平化的可见节点列表
    private func expandDirectory(_ url: URL, depth: Int) -> [FileTreeNodeItem] {
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
                    result.append(contentsOf: expandDirectory(childURL, depth: depth + 1))
                }
            } catch {
                Self.logger.warning("\(Self.t)无法展开目录 \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        return result
    }
    
    /// 切换指定目录的展开状态
    func toggleExpansion(at url: URL) {
        guard let item = items.first(where: { $0.url == url }), item.isDirectory else { return }
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
        guard let index = items.firstIndex(where: { $0.url == url }),
              items[index].isDirectory else { return }
        
        let item = items[index]
        var endIndex = index + 1
        while endIndex < items.count, items[endIndex].depth > item.depth {
            endIndex += 1
        }
        
        if item.isExpanded {
            let newChildren = expandDirectory(url, depth: item.depth)
            items.replaceSubrange(index..<endIndex, with: newChildren)
        } else {
            items[index] = FileTreeNodeItem(
                url: url, depth: item.depth, isDirectory: true,
                isExpanded: false, projectRootPath: projectRootPath,
                fileSystemReader: fileSystemReader
            )
        }
        onItemsChanged?(items)
    }
    
    /// 完全刷新
    func fullRefresh() {
        rebuildItems()
    }
}
