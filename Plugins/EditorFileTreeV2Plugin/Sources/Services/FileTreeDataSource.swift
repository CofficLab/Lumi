import Foundation
import SuperLogKit
import EditorFileTreePlugin

/// 文件树数据源
///
/// 负责将树形结构展平为线性列表，处理展开/折叠状态和精准刷新。
@MainActor
final class FileTreeDataSource: SuperLog {
    nonisolated static let emoji = "🌳"
    nonisolated static var verbose: Bool { EditorFileTreeV2Plugin.verbose }
    nonisolated static let logger = EditorFileTreeV2Plugin.logger
    
    /// 当前扁平化的节点列表（按可见顺序排列）
    private(set) var items: [FileTreeNodeItem] = []
    
    /// 展开状态存储（与现有 FileTreeSettings 兼容）
    private var expandedPaths: Set<String> = []
    
    /// 项目根路径
    private(set) var projectRootPath: String = ""
    
    /// 数据变化回调
    var onItemsChanged: (([FileTreeNodeItem]) -> Void)?
    
    /// 设置项目根目录，重新构建节点列表
    func setProjectRoot(_ path: String) {
        projectRootPath = path
        expandedPaths = FileTreeSettings.shared.expandedPaths(for: path)
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
        let isExpanded = expandedPaths.contains(relativePath)
        let isDirectory = FileTreeFacade.isDirectory(url)
        
        result.append(FileTreeNodeItem(
            url: url, depth: depth, isDirectory: isDirectory,
            isExpanded: isExpanded, projectRootPath: projectRootPath
        ))
        
        if isDirectory && isExpanded {
            do {
                let children = try FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                let sorted = FileTreeFacade.filterAndSortContents(children)
                for childURL in sorted {
                    result.append(contentsOf: expandDirectory(childURL, depth: depth + 1))
                }
            } catch {
                Self.logger.warning("无法展开目录 \(url.lastPathComponent): \(error.localizedDescription)")
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
            FileTreeSettings.shared.removeExpandedPath(relativePath, for: projectRootPath)
            collapseChildren(of: url)
        } else {
            expandedPaths.insert(relativePath)
            FileTreeSettings.shared.addExpandedPath(relativePath, for: projectRootPath)
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
                isExpanded: false, projectRootPath: projectRootPath
            )
        }
        onItemsChanged?(items)
    }
    
    /// 完全刷新
    func fullRefresh() {
        rebuildItems()
    }
}
