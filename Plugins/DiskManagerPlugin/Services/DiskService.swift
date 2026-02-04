import Foundation
import AppKit
import OSLog
import MagicKit

// MARK: - DiskService

@MainActor
class DiskService: ObservableObject, SuperLog {
    static let emoji = "💽"
    static let verbose = true
    static let shared = DiskService()

    @Published var currentScan: ScanProgress?
    @Published var scanHistory: [ScanResult] = []
    
    private let coordinator = ScanCoordinator()
    
    private init() {
        if Self.verbose {
            os_log("\(self.t)磁盘服务已初始化")
        }
        
        // 绑定 Coordinator 的进度更新
        Task {
            for await progress in await coordinator.progressStream {
                self.currentScan = progress
            }
        }
    }
    
    // MARK: - Public API

    func getDiskUsage() -> DiskUsage? {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(total) - Int64(available)
                return DiskUsage(total: Int64(total), used: used, available: Int64(available))
            }
        } catch {
            os_log(.error, "\(self.t)获取磁盘使用情况失败: \(error.localizedDescription)")
        }
        return nil
    }

    /// 扫描指定路径
    func scan(_ path: String, forceRefresh: Bool = true) async throws -> ScanResult {
        if Self.verbose {
            os_log("\(self.t)请求扫描路径: \(path) (forceRefresh: \(forceRefresh))")
        }
        
        // 尝试读取缓存
        if !forceRefresh {
            if let cached = await ScanCacheService.shared.load(for: path) {
                if Self.verbose {
                    os_log("\(self.t)命中缓存")
                }
                return cached
            }
        }
        
        // 执行扫描
        let result = await coordinator.scan(path)
        
        // 保存缓存
        await ScanCacheService.shared.save(result, for: path)
        
        return result
    }

    /// 取消当前扫描
    func cancelScan() {
        Task {
            await coordinator.cancelCurrentScan()
        }
    }
    
    /// 删除文件
    func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    /// 在 Finder 中显示
    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// 计算指定目录的大小（不生成目录树，仅统计总大小）
    func calculateSize(for url: URL) async -> Int64 {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var size: Int64 = 0
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return 0 }
            
            for case let fileURL as URL in enumerator {
                if let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resources.fileSize {
                    size += Int64(fileSize)
                }
            }
            return size
        }.value
    }
}

// MARK: - ScanCoordinator

actor ScanCoordinator {
    private var activeTask: Task<ScanResult, Never>?
    private var currentProgress: ScanProgress? {
        didSet {
            if let progress = currentProgress {
                progressContinuation?.yield(progress)
            }
        }
    }
    
    private var progressContinuation: AsyncStream<ScanProgress>.Continuation?
    let progressStream: AsyncStream<ScanProgress>

    init() {
        var continuation: AsyncStream<ScanProgress>.Continuation?
        self.progressStream = AsyncStream { cont in
            continuation = cont
        }
        self.progressContinuation = continuation
    }

    func scan(_ path: String) async -> ScanResult {
        // 取消之前的任务
        activeTask?.cancel()
        
        let task = Task {
            await performScan(path)
        }
        activeTask = task
        let result = await task.value
        
        // 扫描完成后清除进度
        currentProgress = nil
        return result
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
        currentProgress = nil
    }

    private func performScan(_ path: String) async -> ScanResult {
        let startTime = Date()
        var totalSize: Int64 = 0
        var totalFiles = 0
        var largeFiles = MaxHeap<LargeFileEntry>(capacity: 100)
        
        // 进度追踪
        var scannedFilesCount = 0
        var scannedDirsCount = 0
        var scannedBytesCount: Int64 = 0
        
        // 根目录条目
        var rootChildren: [DirectoryEntry] = []
        
        // 使用 FileManager 进行遍历
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        // 简单的 BFS/DFS 遍历不太适合 TaskGroup 直接映射目录树结构（因为要聚合大小），
        // 但为了性能和响应性，我们可以使用 TaskGroup 并行处理子目录。
        // 这里采用一种混合策略：
        // 1. 对于顶层目录，并行扫描。
        // 2. 递归函数返回 DirectoryEntry (包含大小和子节点)。
        
        // 定义递归扫描函数
        // 注意：Swift Actor 中递归调用 async 函数需要小心重入，但在 TaskGroup 中是安全的。
        
        func scanDir(url: URL, depth: Int) async -> DirectoryEntry? {
            // Check cancellation
            if Task.isCancelled { return nil }
            
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey, .isPackageKey]
            
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                let isDirectory = resourceValues.isDirectory ?? false
                let isPackage = resourceValues.isPackage ?? false
                
                // 如果是文件或者是包（视为文件），直接返回
                if !isDirectory || isPackage {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let modDate = resourceValues.contentModificationDate ?? Date()
                    let accessDate = resourceValues.contentAccessDate ?? Date()
                    
                    // 更新大文件堆
                    if size > 10 * 1024 * 1024 { // > 10MB
                        let entry = LargeFileEntry(
                            id: UUID().uuidString,
                            name: url.lastPathComponent,
                            path: url.path,
                            size: size,
                            modificationDate: modDate,
                            fileType: .from(extension: url.pathExtension)
                        )
                        // 注意：这里是在并发上下文中修改 actor 状态，需要同步？
                        // 不，这里是在 TaskGroup 的 child task 中。
                        // 我们不能直接修改 actor 的 state (largeFiles)。
                        // 我们应该让 scanDir 返回它找到的大文件，然后在父级聚合。
                        // 或者使用 @Sendable closure update actor? Actor reentrancy issue.
                        // 简单做法：scanDir 返回 (Entry, [LargeFileEntry])
                    }
                    
                    return DirectoryEntry(
                        id: UUID().uuidString,
                        name: url.lastPathComponent,
                        path: url.path,
                        size: size,
                        isDirectory: false,
                        lastAccessed: accessDate,
                        modificationDate: modDate,
                        children: nil
                    )
                }
                
                // 是目录，遍历内容
                var children: [DirectoryEntry] = []
                var dirSize: Int64 = 0
                var dirLargeFiles: [LargeFileEntry] = []
                
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                ) else { return nil }
                
                // 收集子项
                var childURLs: [URL] = []
                for case let childURL as URL in enumerator {
                    childURLs.append(childURL)
                }
                
                // 并发处理子项（仅在深度较浅时，避免开启过多 Task）
                if depth < 3 {
                    await withTaskGroup(of: (DirectoryEntry?, [LargeFileEntry]).self) { group in
                        for childURL in childURLs {
                            group.addTask {
                                return await scanRecursive(url: childURL, depth: depth + 1)
                            }
                        }
                        
                        for await (childEntry, childLargeFiles) in group {
                            if let child = childEntry {
                                children.append(child)
                                dirSize += child.size
                                dirLargeFiles.append(contentsOf: childLargeFiles)
                            }
                        }
                    }
                } else {
                    // 深度较深时串行处理，减少开销
                    for childURL in childURLs {
                        let (childEntry, childLFs) = await scanRecursive(url: childURL, depth: depth + 1)
                        if let child = childEntry {
                            children.append(child)
                            dirSize += child.size
                            dirLargeFiles.append(contentsOf: childLFs)
                        }
                    }
                }
                
                // 聚合结果
                // 注意：这里我们只在最后返回聚合后的 LargeFiles，这可能导致内存占用过大。
                // 优化：我们应该只返回 Top N。但这很难在分布式的递归中做。
                // 妥协：我们可以传递一个 actor 引用或者使用一个线程安全的容器来收集大文件？
                // 或者，我们只返回那些确实很大的文件。
                
                return DirectoryEntry(
                    id: UUID().uuidString,
                    name: url.lastPathComponent,
                    path: url.path,
                    size: dirSize,
                    isDirectory: true,
                    lastAccessed: resourceValues.contentAccessDate ?? Date(),
                    modificationDate: resourceValues.contentModificationDate ?? Date(),
                    children: children.sorted { $0.size > $1.size } // 按大小排序子项
                )
            } catch {
                return nil
            }
        }
        
        // 辅助递归函数，返回 (Entry, [LargeFileEntry])
        func scanRecursive(url: URL, depth: Int) async -> (DirectoryEntry?, [LargeFileEntry]) {
            if Task.isCancelled { return (nil, []) }
            
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey, .isPackageKey]
            
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                let isDirectory = resourceValues.isDirectory ?? false
                let isPackage = resourceValues.isPackage ?? false
                
                if !isDirectory || isPackage {
                    // 文件
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let modDate = resourceValues.contentModificationDate ?? Date()
                    var lfs: [LargeFileEntry] = []
                    
                    if size > 50 * 1024 * 1024 { // > 50MB (提高阈值以减少传递数据量)
                        lfs.append(LargeFileEntry(
                            id: UUID().uuidString,
                            name: url.lastPathComponent,
                            path: url.path,
                            size: size,
                            modificationDate: modDate,
                            fileType: .from(extension: url.pathExtension)
                        ))
                    }
                    
                    let entry = DirectoryEntry(
                        id: UUID().uuidString,
                        name: url.lastPathComponent,
                        path: url.path,
                        size: size,
                        isDirectory: false,
                        lastAccessed: resourceValues.contentAccessDate ?? Date(),
                        modificationDate: modDate,
                        children: nil
                    )
                    return (entry, lfs)
                } else {
                    // 目录
                    var children: [DirectoryEntry] = []
                    var dirSize: Int64 = 0
                    var dirLFs: [LargeFileEntry] = []
                    
                    guard let enumerator = fileManager.enumerator(
                        at: url,
                        includingPropertiesForKeys: resourceKeys,
                        options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                    ) else { return (nil, []) }
                    
                    var childURLs: [URL] = []
                    for case let childURL as URL in enumerator {
                        childURLs.append(childURL)
                    }
                    
                    // 限制并发深度
                    if depth < 2 {
                        await withTaskGroup(of: (DirectoryEntry?, [LargeFileEntry]).self) { group in
                            for childURL in childURLs {
                                group.addTask {
                                    return await scanRecursive(url: childURL, depth: depth + 1)
                                }
                            }
                            
                            for await (childEntry, childFiles) in group {
                                if let child = childEntry {
                                    children.append(child)
                                    dirSize += child.size
                                    dirLFs.append(contentsOf: childFiles)
                                }
                            }
                        }
                    } else {
                        for childURL in childURLs {
                            let (childEntry, childFiles) = await scanRecursive(url: childURL, depth: depth + 1)
                            if let child = childEntry {
                                children.append(child)
                                dirSize += child.size
                                dirLFs.append(contentsOf: childFiles)
                            }
                        }
                    }
                    
                    let entry = DirectoryEntry(
                        id: UUID().uuidString,
                        name: url.lastPathComponent,
                        path: url.path,
                        size: dirSize,
                        isDirectory: true,
                        lastAccessed: resourceValues.contentAccessDate ?? Date(),
                        modificationDate: resourceValues.contentModificationDate ?? Date(),
                        children: children.sorted { $0.size > $1.size }
                    )
                    return (entry, dirLFs)
                }
            } catch {
                return (nil, [])
            }
        }
        
        // 开始扫描
        // 为了实时进度更新，我们需要一种方式来统计。
        // 由于递归函数的纯函数性质（不修改外部状态），进度更新比较困难。
        // 我们可以在递归中调用一个 MainActor 的 callback? 或者 actor method?
        // 在 Swift Actor 中，调用 self 方法是同步的（如果不是 async），但这里是 async 递归。
        // 实际上，我们可以简化进度：只在顶层更新，或者传递一个进度更新闭包（但这必须是 @Sendable actor isolated?）
        
        // 重新设计：使用非递归的栈/队列方式，或者保留递归但接受进度不准确。
        // 或者，我们可以简化：先不通过 TaskGroup 递归，而是使用 `FileManager.enumerator` 遍历整个树（就像之前的实现），
        // 并在遍历过程中构建树结构。
        // 但是构建树结构需要自底向上的聚合（计算文件夹大小）。
        // 之前的实现只找大文件，不构建树。
        // 现在要构建树，必须后序遍历（Post-order traversal）。
        
        // 鉴于实现复杂度和性能，我们可以采用两步走：
        // 1. 快速扫描整个文件列表（扁平），同时统计大文件和进度。
        // 2. 将扁平列表组装成树（如果需要）。
        // 但这样内存消耗巨大。
        
        // 回到递归方案：
        // 我们可以只在处理完每个目录时更新进度。
        // 为了简单起见，这里先实现核心逻辑，进度更新可以在顶层 TaskGroup 的结果处理中做估算，
        // 或者在递归函数中每处理 N 个文件 update 一次 actor state (await self.updateProgress(...))
        
        // 为了避免复杂的 Sendable 问题，我们简化一下：
        // 进度更新通过一个独立的 Task 定时轮询？不，无法获知内部状态。
        // 我们在递归中传入一个 @Sendable closure 来更新进度。
        
        // 定义一个线程安全的计数器类
        final class ProgressCounter: @unchecked Sendable {
            private let lock = NSLock()
            var files = 0
            var size: Int64 = 0
            
            func increment(size: Int64) {
                lock.lock()
                self.files += 1
                self.size += size
                lock.unlock()
            }
            
            var current: (Int, Int64) {
                lock.lock()
                defer { lock.unlock() }
                return (files, size)
            }
        }
        
        let counter = ProgressCounter()
        
        // 启动一个定时器更新进度
        let progressTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500 * 1_000_000) // 0.5s
                let (files, size) = counter.current
                self.currentProgress = ScanProgress(
                    path: path,
                    currentPath: "Scanning...", // 简化
                    scannedFiles: files,
                    scannedDirectories: 0,
                    scannedBytes: size,
                    startTime: startTime
                )
            }
        }
        
        // 重新实现递归，带 counter
        func scanRecursiveWithCounter(url: URL, depth: Int) async -> (DirectoryEntry?, [LargeFileEntry]) {
            if Task.isCancelled { return (nil, []) }
            
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey, .isPackageKey]
            
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                let isDirectory = resourceValues.isDirectory ?? false
                let isPackage = resourceValues.isPackage ?? false
                
                if !isDirectory || isPackage {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    counter.increment(size: size) // Update progress
                    
                    let modDate = resourceValues.contentModificationDate ?? Date()
                    var lfs: [LargeFileEntry] = []
                    
                    if size > 50 * 1024 * 1024 {
                        lfs.append(LargeFileEntry(
                            id: UUID().uuidString,
                            name: url.lastPathComponent,
                            path: url.path,
                            size: size,
                            modificationDate: modDate,
                            fileType: .from(extension: url.pathExtension)
                        ))
                    }
                    
                    let entry = DirectoryEntry(
                        id: UUID().uuidString,
                        name: url.lastPathComponent,
                        path: url.path,
                        size: size,
                        isDirectory: false,
                        lastAccessed: resourceValues.contentAccessDate ?? Date(),
                        modificationDate: modDate,
                        children: nil
                    )
                    return (entry, lfs)
                } else {
                    var children: [DirectoryEntry] = []
                    var dirSize: Int64 = 0
                    var dirLFs: [LargeFileEntry] = []
                    
                    guard let enumerator = fileManager.enumerator(
                        at: url,
                        includingPropertiesForKeys: resourceKeys,
                        options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                    ) else { return (nil, []) }
                    
                    var childURLs: [URL] = []
                    for case let childURL as URL in enumerator {
                        childURLs.append(childURL)
                    }
                    
                    if depth < 2 {
                        await withTaskGroup(of: (DirectoryEntry?, [LargeFileEntry]).self) { group in
                            for childURL in childURLs {
                                group.addTask {
                                    return await scanRecursiveWithCounter(url: childURL, depth: depth + 1)
                                }
                            }
                            for await (childEntry, childFiles) in group {
                                if let child = childEntry {
                                    children.append(child)
                                    dirSize += child.size
                                    dirLFs.append(contentsOf: childFiles)
                                }
                            }
                        }
                    } else {
                        for childURL in childURLs {
                            let (childEntry, childFiles) = await scanRecursiveWithCounter(url: childURL, depth: depth + 1)
                            if let child = childEntry {
                                children.append(child)
                                dirSize += child.size
                                dirLFs.append(contentsOf: childFiles)
                            }
                        }
                    }
                    
                    let entry = DirectoryEntry(
                        id: UUID().uuidString,
                        name: url.lastPathComponent,
                        path: url.path,
                        size: dirSize,
                        isDirectory: true,
                        lastAccessed: resourceValues.contentAccessDate ?? Date(),
                        modificationDate: resourceValues.contentModificationDate ?? Date(),
                        children: children.sorted { $0.size > $1.size }
                    )
                    return (entry, dirLFs)
                }
            } catch {
                return (nil, [])
            }
        }
        
        // Execute scan
        let (rootEntry, allLargeFiles) = await scanRecursiveWithCounter(url: url, depth: 0)
        
        progressTimer.cancel()
        
        // Finalize results
        for file in allLargeFiles {
            largeFiles.insert(file)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let (totalFilesCount, totalBytes) = counter.current
        
        return ScanResult(
            entries: rootEntry?.children ?? [],
            largeFiles: largeFiles.elements,
            totalSize: totalBytes,
            totalFiles: totalFilesCount,
            scanDuration: duration,
            scannedAt: Date()
        )
    }
}
