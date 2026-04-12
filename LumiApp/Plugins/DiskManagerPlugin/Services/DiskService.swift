import Foundation
import AppKit
import MagicKit

/// 磁盘服务 - 在后台执行扫描和清理操作
class DiskService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "💽"
    nonisolated static let verbose: Bool = true    static let shared = DiskService()

    private let coordinator = ScanCoordinator()

    // 注意：状态管理已移至 ViewModel，Service 只负责后台操作
    private init() {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)Disk service initialized")
        }
    }

    // MARK: - Public API

    func getDiskUsage() async -> DiskUsage? {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)获取磁盘使用情况")
        }
        return await Task.detached(priority: .userInitiated) {
            let fileURL = URL(fileURLWithPath: "/")
            do {
                let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
                if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                    let used = Int64(total) - Int64(available)
                    if Self.verbose {
                        DiskManagerPlugin.logger.info("\(Self.t)磁盘使用：已用 \(ByteCountFormatter.string(fromByteCount: used, countStyle: .file))，可用 \(ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file))")
                    }
                    return DiskUsage(total: Int64(total), used: used, available: Int64(available))
                }
            } catch {
                DiskManagerPlugin.logger.error("\(Self.t)获取磁盘使用失败：\(error.localizedDescription)")
            }
            return nil
        }.value
    }

    /// Scan specified path
    func scan(_ path: String, forceRefresh: Bool = true) async throws -> ScanResult {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)Request scanning path: \(path) (forceRefresh: \(forceRefresh))")
        }

        // Try to read cache
        if !forceRefresh {
            if let cached = await ScanCacheService.shared.load(for: path) {
                if Self.verbose {
                    DiskManagerPlugin.logger.info("\(self.t)缓存命中：\((path as NSString).lastPathComponent)")
                }
                return cached
            }
        }

        // Execute scan
        DiskManagerPlugin.logger.info("\(self.t)开始扫描路径：\((path as NSString).lastPathComponent)")
        let result = await coordinator.scan(path)
        DiskManagerPlugin.logger.info("\(self.t)扫描完成：\((path as NSString).lastPathComponent)，\(result.largeFiles.count) 个大文件，\(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))")

        // Save cache
        await ScanCacheService.shared.save(result, for: path)

        return result
    }

    /// Cancel current scan
    func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    /// Delete file
    func deleteFile(at url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: url)
        }.value
    }

    /// Reveal in Finder
    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Calculate the size of the specified directory (does not generate directory tree, only counts total size)
    func calculateSize(for url: URL) async -> Int64 {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var size: Int64 = 0

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return 0 }

            // Collect URLs synchronously to avoid non-Sendable enumerator in async context
            var fileURLs: [URL] = []
            while let fileURL = enumerator.nextObject() as? URL {
                fileURLs.append(fileURL)
            }

            for fileURL in fileURLs {
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
    init() {}

    func scan(_ path: String) async -> ScanResult {
        // Cancel previous task
        activeTask?.cancel()
        
        let task = Task {
            await performScan(path)
        }
        activeTask = task
        let result = await task.value
        return result
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
    }

    private func performScan(_ path: String) async -> ScanResult {
        let startTime = Date()
        var largeFiles = MaxHeap<LargeFileEntry>(capacity: 100)
        
        let url = URL(fileURLWithPath: path)
        let counter = ProgressCounter()

        // Execute scan
        let (rootEntry, allLargeFiles) = await Self.scanRecursiveHelper(url: url, depth: 0, counter: counter)
        
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

    private static func scanRecursiveHelper(url: URL, depth: Int, counter: ProgressCounter) async -> (DirectoryEntry?, [LargeFileEntry]) {
        if Task.isCancelled { return (nil, []) }
        
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey, .isPackageKey]
        let fileManager = FileManager.default
        
        do {
            let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = resourceValues.isDirectory ?? false
            let isPackage = resourceValues.isPackage ?? false
            
            if !isDirectory || isPackage {
                let size = Int64(resourceValues.fileSize ?? 0)
                counter.increment(size: size)
                
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
                // Count the directory itself as an item
                counter.increment(size: Int64(resourceValues.fileSize ?? 0))

                var children: [DirectoryEntry] = []
                var dirSize: Int64 = 0
                var dirLFs: [LargeFileEntry] = []

                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                ) else { return (nil, []) }

                var childURLs: [URL] = []
                while let childURL = enumerator.nextObject() as? URL {
                    childURLs.append(childURL)
                }

                if depth < 2 {
                    await withTaskGroup(of: (DirectoryEntry?, [LargeFileEntry]).self) { group in
                        for childURL in childURLs {
                            group.addTask {
                                return await scanRecursiveHelper(url: childURL, depth: depth + 1, counter: counter)
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
                        let (childEntry, childFiles) = await scanRecursiveHelper(url: childURL, depth: depth + 1, counter: counter)
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
}

// MARK: - Helpers

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
