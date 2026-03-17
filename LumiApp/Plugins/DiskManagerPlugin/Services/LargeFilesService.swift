import Foundation
import AppKit
import OSLog
import MagicKit

/// 大文件相关服务：扫描、进度、删除、Finder 展示
final class LargeFilesService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose = true

    static let shared = LargeFilesService()

    private let coordinator = LargeFilesScanCoordinator()

    private init() {}

    func scanLargeFiles(atPath path: String, forceRefresh: Bool = true) async throws -> [LargeFileEntry] {
        if Self.verbose {
            os_log("\(self.t)开始扫描大文件：\((path as NSString).lastPathComponent)")
        }
        // 当前仅实现“扫描”能力；forceRefresh 保留签名以兼容调用方
        _ = forceRefresh
        let result = await coordinator.scanLargeFiles(path: path)
        if Self.verbose {
            os_log("\(self.t)大文件扫描完成：\((path as NSString).lastPathComponent)，发现 \(result.count) 个大文件")
        }
        return result
    }

    func progressStream() async -> AsyncStream<ScanProgress> {
        await coordinator.progressStream()
    }

    func cancelScan() async {
        if Self.verbose {
            os_log("\(self.t)停止扫描大文件")
        }
        await coordinator.cancelCurrentScan()
    }

    func deleteFile(atPath path: String) async throws {
        if Self.verbose {
            os_log("\(self.t)删除大文件：\((path as NSString).lastPathComponent)")
        }
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }.value
    }

    @MainActor
    func revealInFinder(path: String) {
        if Self.verbose {
            os_log("\(self.t)在访达中显示：\((path as NSString).lastPathComponent)")
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

// MARK: - LargeFilesScanCoordinator

actor LargeFilesScanCoordinator {
    private var activeTask: Task<[LargeFileEntry], Never>?
    private var lastPath: String?
    private var scannedFiles: Int = 0
    private var scannedDirectories: Int = 0
    private var scannedBytes: Int64 = 0
    private var startTime: Date?

    private var currentProgress: ScanProgress? {
        didSet {
            if let progress = currentProgress {
                // Broadcast to all subscribers
                for (_, cont) in progressContinuations {
                    cont.yield(progress)
                }
            }
        }
    }

    private var progressContinuations: [UUID: AsyncStream<ScanProgress>.Continuation] = [:]

    private var streamSubscribers: Int { progressContinuations.count }
    private var emitCount: Int = 0
    private var lastEmitLogAt: Date = .distantPast

    init() {}

    func progressStream() -> AsyncStream<ScanProgress> {
        let id = UUID()
        if LargeFilesService.verbose {
            os_log("\(LargeFilesService.t)[Coordinator] progressStream subscribed (\(self.streamSubscribers + 1))")
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
        // New subscriber gets the latest snapshot immediately if available
        if let progress = currentProgress {
            continuation.yield(progress)
        }
    }

    private func removeContinuation(id: UUID) {
        progressContinuations[id] = nil
        if LargeFilesService.verbose {
            os_log("\(LargeFilesService.t)[Coordinator] progressStream unsubscribed (\(self.streamSubscribers))")
        }
    }

    func scanLargeFiles(path: String) async -> [LargeFileEntry] {
        if LargeFilesService.verbose {
            os_log("\(LargeFilesService.t)[Coordinator] scan start: \(path)")
        }
        activeTask?.cancel()

        scannedFiles = 0
        scannedDirectories = 0
        scannedBytes = 0
        lastPath = path
        startTime = Date()
        emitCount = 0
        lastEmitLogAt = .distantPast

        // 立刻推送一次进度，避免 UI 长时间停留在“准备扫描”
        currentProgress = ScanProgress(
            path: path,
            currentPath: path,
            scannedFiles: 0,
            scannedDirectories: 0,
            scannedBytes: 0,
            startTime: startTime ?? Date()
        )
        logEmitSnapshot(reason: "initial")

        let task = Task { await performScan(path: path) }
        activeTask = task
        let result = await task.value

        currentProgress = nil
        startTime = nil
        if LargeFilesService.verbose {
            os_log("\(LargeFilesService.t)[Coordinator] scan end: files=\(self.scannedFiles) dirs=\(self.scannedDirectories) bytes=\(self.scannedBytes) emits=\(self.emitCount)")
        }
        return result
    }

    func cancelCurrentScan() {
        if LargeFilesService.verbose {
            os_log("\(LargeFilesService.t)[Coordinator] cancel scan")
        }
        activeTask?.cancel()
        activeTask = nil
        currentProgress = nil
        startTime = nil
    }

    private func performScan(path: String) async -> [LargeFileEntry] {
        let rootURL = URL(fileURLWithPath: path)
        let fm = FileManager.default

        let start = startTime ?? Date()
        var lastEmitAt = Date.distantPast

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var top = MaxHeap<LargeFileEntry>(capacity: 100)

        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }

            lastPath = url.path

            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey]) else {
                continue
            }

            let isDirectory = values.isDirectory ?? false
            let isPackage = values.isPackage ?? false
            if isDirectory, !isPackage {
                scannedDirectories += 1
                Self.maybeEmitProgress(
                    lastEmitAt: &lastEmitAt,
                    emit: { self.emitProgressSnapshot(path: path, start: start) }
                )
                continue
            }

            let size = Int64(values.fileSize ?? 0)
            scannedFiles += 1
            scannedBytes += size
            Self.maybeEmitProgress(
                lastEmitAt: &lastEmitAt,
                emit: { self.emitProgressSnapshot(path: path, start: start) }
            )

            if size > 50 * 1024 * 1024 {
                let entry = LargeFileEntry(
                    id: UUID().uuidString,
                    name: url.lastPathComponent,
                    path: url.path,
                    size: size,
                    modificationDate: values.contentModificationDate ?? Date(),
                    fileType: .from(extension: url.pathExtension)
                )
                top.insert(entry)
            }
        }

        emitProgressSnapshot(path: path, start: start)
        return top.elements
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
        emitCount += 1
        logEmitSnapshot(reason: "tick")
    }

    nonisolated private static func maybeEmitProgress(lastEmitAt: inout Date, emit: () -> Void) {
        let now = Date()
        if now.timeIntervalSince(lastEmitAt) >= 0.5 {
            lastEmitAt = now
            emit()
        }
    }

    private func logEmitSnapshot(reason: String) {
        guard LargeFilesService.verbose else { return }
        let now = Date()
        if reason != "initial", now.timeIntervalSince(lastEmitLogAt) < 2.0 { return }
        lastEmitLogAt = now
        os_log(
            "\(LargeFilesService.t)[Coordinator] emit(\(reason)) files=\(self.scannedFiles) dirs=\(self.scannedDirectories) bytes=\(self.scannedBytes) path=\((self.lastPath ?? "").isEmpty ? "-" : (self.lastPath ?? "-"))"
        )
    }
}

