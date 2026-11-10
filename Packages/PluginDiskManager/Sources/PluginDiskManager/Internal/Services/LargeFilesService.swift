import AppKit
import Foundation

/// Large files service: scan, progress, delete, Finder reveal.
public final class LargeFilesService: @unchecked Sendable {
    public static let shared = LargeFilesService()

    private let coordinator = LargeFilesScanCoordinator()

    private init() {}

    public func scanLargeFiles(atPath path: String, forceRefresh: Bool = true) async throws -> [LargeFileEntry] {
        _ = forceRefresh
        return try await coordinator.scanLargeFiles(path: path)
    }

    public func progressStream() async -> AsyncStream<ScanProgress> {
        await coordinator.progressStream()
    }

    public func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    public func deleteFile(atPath path: String) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }.value
        // 删除成功即意味着磁盘用量变化，通知仍在展示的容量文字与环形图刷新。
        await MainActor.run {
            NotificationCenter.default.post(name: .diskManagerDiskUsageDidChange, object: nil)
        }
    }

    @MainActor
    public func revealInFinder(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

// MARK: - LargeFilesScanCoordinator

actor LargeFilesScanCoordinator {
    private var activeTask: Task<[LargeFileEntry], Error>?
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

    init() {}

    func progressStream() -> AsyncStream<ScanProgress> {
        let id = UUID()
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
    }

    func scanLargeFiles(path: String) async throws -> [LargeFileEntry] {
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

        let task = Task { try await performScan(path: path) }
        activeTask = task

        do {
            let result = try await task.value
            currentProgress = nil
            startTime = nil
            return result
        } catch {
            currentProgress = nil
            startTime = nil
            throw error
        }
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
        activeTask = nil
        currentProgress = nil
        startTime = nil
    }

    private func performScan(path: String) async throws -> [LargeFileEntry] {
        let rootURL = URL(fileURLWithPath: path)

        let start = startTime ?? Date()
        var lastEmitAt = Date.distantPast

        let enumerator = try ScanRootEnumerator.make(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

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
    }

    nonisolated private static func maybeEmitProgress(lastEmitAt: inout Date, emit: () -> Void) {
        let now = Date()
        if now.timeIntervalSince(lastEmitAt) >= 0.5 {
            lastEmitAt = now
            emit()
        }
    }
}
