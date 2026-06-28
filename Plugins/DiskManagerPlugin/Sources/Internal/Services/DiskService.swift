import AppKit
import Foundation
import os
import SuperLogKit

/// Disk service - performs scanning and cleaning operations in the background.
public final class DiskService: SuperLog, @unchecked Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "disk")
    nonisolated(unsafe) static var verbose: Bool = false
    public static let shared = DiskService()

    private let coordinator = ScanCoordinator()

    private init() {}

    // MARK: - Public API

    public func getDiskUsage() async -> DiskUsage? {
        await Task.detached(priority: .userInitiated) {
            let fileURL = URL(fileURLWithPath: "/")
            do {
                let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
                if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                    let used = Int64(total) - Int64(available)
                    return DiskUsage(total: Int64(total), used: used, available: Int64(available))
                }
            } catch {
                if Self.verbose {
                                    Self.logger.error("\(Self.t)Failed to get disk usage: \(error.localizedDescription)")
                }
            }
            return nil
        }.value
    }

    public func scan(_ path: String, forceRefresh: Bool = true) async throws -> ScanResult {
        if let cached = await ScanCacheService.shared.load(for: path), !forceRefresh {
            return cached
        }

        let result = await coordinator.scan(path)
        await ScanCacheService.shared.save(result, for: path)
        return result
    }

    public func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    public func deleteFile(at url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: url)
        }.value
    }

    @MainActor
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func calculateSize(for url: URL) async -> Int64 {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            var size: Int64 = 0

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return 0 }

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
        activeTask?.cancel()

        let task = Task {
            await performScan(path)
        }
        activeTask = task
        return await task.value
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
    }

    private func performScan(_ path: String) async -> ScanResult {
        let startTime = Date()
        var largeFiles = MaxHeap<LargeFileEntry>(capacity: 100)

        let url = URL(fileURLWithPath: path)
        let counter = ProgressCounter()

        let (rootEntry, allLargeFiles) = await Self.scanRecursiveHelper(url: url, depth: 0, counter: counter)

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

public final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    public var files = 0
    public var size: Int64 = 0

    public func increment(size: Int64) {
        lock.lock()
        self.files += 1
        self.size += size
        lock.unlock()
    }

    public var current: (Int, Int64) {
        lock.lock()
        defer { lock.unlock() }
        return (files, size)
    }
}
