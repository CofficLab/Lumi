import Foundation
import AppKit
import OSLog
import MagicKit

/// 目录结构分析服务：扫描、进度、取消、Finder 展示
final class DirectoryTreeService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true

    static let shared = DirectoryTreeService()
    private let coordinator = DirectoryTreeScanCoordinator()

    private init() {}

    func scanDirectoryTree(atPath path: String) async throws -> [DirectoryEntry] {
        if Self.verbose {
            os_log("\(self.t)开始分析目录结构：\((path as NSString).lastPathComponent)")
        }
        let result = await coordinator.scan(path: path)
        if Self.verbose {
            os_log("\(self.t)目录结构分析完成：\((path as NSString).lastPathComponent)，根节点 \(result.count) 个")
        }
        return result
    }

    func progressStream() async -> AsyncStream<ScanProgress> {
        await coordinator.progressStream()
    }

    func cancelScan() async {
        if Self.verbose {
            os_log("\(self.t)停止分析目录结构")
        }
        await coordinator.cancelCurrentScan()
    }

    @MainActor
    func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

// MARK: - Coordinator

actor DirectoryTreeScanCoordinator {
    private var activeTask: Task<[DirectoryEntry], Never>?

    private var lastPath: String?
    private var scannedFiles: Int = 0
    private var scannedDirectories: Int = 0
    private var scannedBytes: Int64 = 0
    private var startTime: Date?

    private var currentProgress: ScanProgress? {
        didSet {
            if let progress = currentProgress {
                for (_, cont) in progressContinuations {
                    cont.yield(progress)
                }
            }
        }
    }

    private var progressContinuations: [UUID: AsyncStream<ScanProgress>.Continuation] = [:]

    func progressStream() -> AsyncStream<ScanProgress> {
        let id = UUID()
        if DirectoryTreeService.verbose {
            os_log("\(DirectoryTreeService.t)[Coordinator] progressStream subscribed (\(self.progressContinuations.count + 1))")
        }
        return AsyncStream { continuation in
            Task { await self.addContinuation(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<ScanProgress>.Continuation) {
        progressContinuations[id] = continuation
        if let progress = currentProgress {
            continuation.yield(progress)
        }
    }

    private func removeContinuation(id: UUID) {
        progressContinuations[id] = nil
        if DirectoryTreeService.verbose {
            os_log("\(DirectoryTreeService.t)[Coordinator] progressStream unsubscribed (\(self.progressContinuations.count))")
        }
    }

    func scan(path: String) async -> [DirectoryEntry] {
        activeTask?.cancel()

        scannedFiles = 0
        scannedDirectories = 0
        scannedBytes = 0
        lastPath = path
        startTime = Date()

        currentProgress = ScanProgress(
            path: path,
            currentPath: path,
            scannedFiles: 0,
            scannedDirectories: 0,
            scannedBytes: 0,
            startTime: startTime ?? Date()
        )

        let task = Task { await buildTree(rootPath: path) }
        activeTask = task
        let result = await task.value

        currentProgress = nil
        startTime = nil
        finishAllProgressStreams()
        return result
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
        activeTask = nil
        currentProgress = nil
        startTime = nil
        finishAllProgressStreams()
    }

    private func buildTree(rootPath: String) async -> [DirectoryEntry] {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var dirSizes: [String: Int64] = [:]

        let start = startTime ?? Date()
        var lastEmitAt = Date.distantPast

        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            lastPath = url.path

            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey, .contentAccessDateKey]) else {
                continue
            }

            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            if isDirectory, !isPackage {
                scannedDirectories += 1
                maybeEmitProgress(lastEmitAt: &lastEmitAt, emit: { self.emitProgressSnapshot(path: rootPath, start: start) })
                continue
            }

            let size = Int64(values.fileSize ?? 0)
            scannedFiles += 1
            scannedBytes += size
            maybeEmitProgress(lastEmitAt: &lastEmitAt, emit: { self.emitProgressSnapshot(path: rootPath, start: start) })

            // Aggregate size into all ancestor directories (up to rootPath)
            var parentURL = url.deletingLastPathComponent()
            while parentURL.path.hasPrefix(rootPath), parentURL.path != rootPath {
                dirSizes[parentURL.path, default: 0] += size
                parentURL = parentURL.deletingLastPathComponent()
            }
        }

        // Build directory tree bottom-up (avoid stale value-type copies)
        let allDirPaths = Array(dirSizes.keys)
        let sortedByDepthDesc = allDirPaths.sorted {
            $0.split(separator: "/").count > $1.split(separator: "/").count
        }

        var built: [String: DirectoryEntry] = [:]
        for dirPath in sortedByDepthDesc {
            let url = URL(fileURLWithPath: dirPath)
            let children = built.values
                .filter { URL(fileURLWithPath: $0.path).deletingLastPathComponent().path == dirPath }
                .sorted { $0.size > $1.size }

            built[dirPath] = DirectoryEntry(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                path: dirPath,
                size: dirSizes[dirPath] ?? 0,
                isDirectory: true,
                lastAccessed: Date(),
                modificationDate: Date(),
                children: children
            )
        }

        // Root entries: children of rootPath
        let rootChildren = built.values
            .filter { URL(fileURLWithPath: $0.path).deletingLastPathComponent().path == rootPath }
            .sorted { $0.size > $1.size }

        emitProgressSnapshot(path: rootPath, start: start)
        return rootChildren
    }

    private func emitProgressSnapshot(path: String, start: Date) {
        let current = lastPath ?? path
        currentProgress = ScanProgress(
            path: path,
            currentPath: current,
            scannedFiles: scannedFiles,
            scannedDirectories: scannedDirectories,
            scannedBytes: scannedBytes,
            startTime: start
        )
    }

    nonisolated private func maybeEmitProgress(lastEmitAt: inout Date, emit: () -> Void) {
        let now = Date()
        if now.timeIntervalSince(lastEmitAt) >= 0.5 {
            lastEmitAt = now
            emit()
        }
    }

    private func finishAllProgressStreams() {
        for (_, cont) in progressContinuations {
            cont.finish()
        }
        progressContinuations.removeAll()
    }
}

