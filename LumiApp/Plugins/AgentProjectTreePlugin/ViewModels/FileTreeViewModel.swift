import Foundation
import SwiftUI
import Combine
import OSLog
import MagicKit

/// 文件树视图模型 - 管理文件树的所有状态和逻辑
@MainActor
final class FileTreeViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🌲"
    nonisolated static let verbose = true
    
    /// 项目根目录
    @Published var projectRoot: URL?
    
    /// 根节点列表
    @Published var rootNodes: [FileTreeNode] = []
    
    /// 是否正在加载
    @Published var isLoading = false
    
    /// 选中的文件 URL
    @Published var selectedFileURL: URL?
    
    /// 展开的节点 URL 集合
    @Published var expandedURLs: Set<URL> = []
    
    /// 加载中的节点 URL 集合
    @Published var loadingURLs: Set<URL> = []
    
    /// 子节点缓存 - 避免重复读取磁盘
    private var childrenCache: [URL: [FileTreeNode]] = [:]
    
    /// 文件监控器
    private var fileMonitor: FileMonitor?
    
    /// 取消令牌集合
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// 加载项目文件树
    func loadProject(at path: String) {
        guard !path.isEmpty else {
            os_log("\(Self.t)⚠️ 项目路径为空")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        guard url != projectRoot else {
            os_log("\(Self.t)⏭️ 相同项目，跳过加载")
            return
        }
        
        os_log("\(Self.t)📂 开始加载项目: \(path)")
        
        isLoading = true
        projectRoot = url
        
        // 清空缓存
        childrenCache.removeAll()
        expandedURLs.removeAll()
        
        Task {
            let nodes = await loadDirectoryContents(url: url, depth: 0)
            
            await MainActor.run {
                self.rootNodes = nodes
                self.isLoading = false
                os_log("\(Self.t)✅ 项目加载完成: \(nodes.count) 个根项")
            }
            
            // 启动文件监控
            self.startMonitoring(url: url)
        }
    }
    
    /// 刷新文件树
    func refresh() {
        guard let root = projectRoot else {
            os_log("\(Self.t)⚠️ 没有项目可刷新")
            return
        }
        
        os_log("\(Self.t)🔄 刷新文件树")
        
        // 清空缓存
        childrenCache.removeAll()
        
        Task {
            let nodes = await loadDirectoryContents(url: root, depth: 0)
            
            await MainActor.run {
                self.rootNodes = nodes
                os_log("\(Self.t)✅ 刷新完成: \(nodes.count) 个根项")
            }
        }
    }
    
    /// 切换节点展开/折叠状态
    func toggleExpansion(for url: URL) {
        if expandedURLs.contains(url) {
            expandedURLs.remove(url)
            os_log("\(Self.t)📁 折叠: \(url.lastPathComponent)")
        } else {
            expandedURLs.insert(url)
            os_log("\(Self.t)📂 展开: \(url.lastPathComponent)")
            
            // 如果是首次展开，加载子节点
            if childrenCache[url] == nil {
                loadChildren(for: url)
            }
        }
        
        // 保存展开状态
        FileTreeStateManager.shared.setExpanded(expandedURLs.contains(url), url: url, projectPath: projectRoot?.path ?? "")
    }
    
    /// 获取节点的子节点
    func children(for url: URL) -> [FileTreeNode] {
        return childrenCache[url] ?? []
    }
    
    /// 检查节点是否展开
    func isExpanded(_ url: URL) -> Bool {
        return expandedURLs.contains(url)
    }
    
    /// 检查节点是否正在加载
    func isLoading(_ url: URL) -> Bool {
        return loadingURLs.contains(url)
    }
    
    /// 选择文件
    func selectFile(_ url: URL) {
        selectedFileURL = url
        os_log("\(Self.t)👆 选中文件: \(url.lastPathComponent)")
    }
    
    /// 处理文件拖放
    func handleFileDrop(_ url: URL) {
        os_log("\(Self.t)📥 文件拖放: \(url.lastPathComponent)")
        // TODO: 实现文件拖放逻辑
    }
    
    // MARK: - Private Methods
    
    /// 加载目录内容
    private func loadDirectoryContents(url: URL, depth: Int) async -> [FileTreeNode] {
        // 检查缓存
        if let cached = childrenCache[url] {
            return cached
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            
            let nodes = contents.compactMap { itemURL -> FileTreeNode? in
                guard let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .nameKey]),
                      let name = resourceValues.name else {
                    return nil
                }
                
                let isDirectory = resourceValues.isDirectory ?? false
                
                return FileTreeNode(
                    name: name,
                    url: itemURL,
                    isDirectory: isDirectory,
                    isExpanded: false,
                    children: nil
                )
            }
            
            // 排序：文件夹在前，按名称排序
            let sortedNodes = nodes.sorted { left, right in
                if left.isDirectory == right.isDirectory {
                    return left.name.localizedStandardCompare(right.name) == .orderedAscending
                }
                return left.isDirectory
            }
            
            // 存入缓存
            childrenCache[url] = sortedNodes
            
            return sortedNodes
            
        } catch {
            os_log("\(Self.t)❌ 读取目录失败: \(url.lastPathComponent), error: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 加载子节点（用于延迟加载）
    private func loadChildren(for url: URL) {
        guard !loadingURLs.contains(url) else { return }
        
        loadingURLs.insert(url)
        os_log("\(Self.t)⏳ 加载子节点: \(url.lastPathComponent)")
        
        Task {
            let children = await loadDirectoryContents(url: url, depth: 1)
            
            await MainActor.run {
                self.childrenCache[url] = children
                self.loadingURLs.remove(url)
                os_log("\(Self.t)✅ 子节点加载完成: \(url.lastPathComponent), \(children.count) 个项")
            }
        }
    }
    
    /// 启动文件监控
    private func startMonitoring(url: URL) {
        fileMonitor?.stop()
        fileMonitor = FileMonitor(directory: url)
        
        fileMonitor?.onChange = { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        
        fileMonitor?.start()
        os_log("\(Self.t)👁️ 启动文件监控: \(url.path)")
    }
    
    deinit {
        fileMonitor?.stop()
        os_log("\(Self.t)🗑️ FileTreeViewModel 释放")
    }
}

// MARK: - File Monitor

/// 简单的文件系统监控器
private final class FileMonitor: @unchecked Sendable {
    private let directory: URL
    private var source: DispatchSourceFileSystemObject?
    private let fileDescriptor: Int32
    
    var onChange: (() -> Void)?
    
    init(directory: URL) {
        self.directory = directory
        self.fileDescriptor = open(directory.path, O_EVTONLY)
    }
    
    func start() {
        guard fileDescriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: DispatchQueue.global()
        )
        
        source?.setEventHandler { [weak self] in
            self?.onChange?()
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
        close(fileDescriptor)
    }
    
    deinit {
        stop()
    }
}
