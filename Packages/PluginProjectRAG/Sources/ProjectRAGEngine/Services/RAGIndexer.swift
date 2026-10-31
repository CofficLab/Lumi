import Foundation
import LumiLoggingKit
import os

public struct RAGIndexer: SuperLog, Sendable {
    public nonisolated static let emoji = "📇"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag.indexer")

    private let store: any RAGStore
    private let chunker: RAGChunker
    private let embeddingProvider: RAGEmbeddingProvider

    /// 索引进度回调。
    ///
    /// - Note: 标注 `@Sendable` 是为了满足 Swift 6 的严格并发检查——
    ///   索引方法会在 `await`（让出时间片）后跨线程恢复，因此索引器本身
    ///   必须是 `Sendable`。
    private let onProgress: (@Sendable (RAGIndexProgressEvent) -> Void)?

    private static let progressLogInterval = 50

    init(
        store: any RAGStore,
        embeddingProvider: RAGEmbeddingProvider,
        onProgress: (@Sendable (RAGIndexProgressEvent) -> Void)? = nil
    ) {
        self.store = store
        self.chunker = RAGChunker()
        self.embeddingProvider = embeddingProvider
        self.onProgress = onProgress
    }

    public func rebuildProjectIndex(
        at projectPath: String,
        background: Bool = false,
        shouldContinue: @escaping @Sendable () -> Bool = { true }
    ) async throws -> RAGIndexStats {
        let files = RAGFileScanner.discoverFiles(in: projectPath)
        let indexedStates = try store.fetchIndexedFileStates(projectPath: projectPath)
        if Self.verbose {
            Self.logger.info("\(Self.t)全量重建开始 files=\(files.count) oldIndexedFiles=\(indexedStates.count)")
        }

        for state in indexedStates.values {
            try store.deleteChunks(projectPath: projectPath, filePath: state.filePath)
            try store.deleteFileState(projectPath: projectPath, filePath: state.filePath)
        }

        var stats = try await indexFiles(files, projectPath: projectPath, background: background, shouldContinue: shouldContinue)
        let fileCount = try store.countProjectFiles(projectPath: projectPath)
        let chunkCount = try store.countProjectChunks(projectPath: projectPath)
        try store.upsertProjectIndexState(
            projectPath: projectPath,
            fileCount: fileCount,
            chunkCount: chunkCount,
            embeddingModel: embeddingProvider.modelIdentifierWithVersion,
            embeddingDimension: embeddingProvider.dimension
        )
        stats.chunkCount = chunkCount
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)全量重建结束 scanned=\(stats.scannedFiles) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) fileCount=\(fileCount) chunkCount=\(chunkCount)"
            )
        }
        return stats
    }

    public func indexProjectIncrementally(
        at projectPath: String,
        background: Bool = false,
        shouldContinue: @escaping @Sendable () -> Bool = { true }
    ) async throws -> RAGIndexStats {
        let files = RAGFileScanner.discoverFiles(in: projectPath)
        if Self.verbose {
            Self.logger.info("\(Self.t)增量索引开始 files=\(files.count)")
        }
        var stats = try await indexFiles(files, projectPath: projectPath, background: background, shouldContinue: shouldContinue)

        // 删除已被移除的文件索引
        let existing = try store.fetchIndexedFileStates(projectPath: projectPath)
        let currentSet = Set(files)
        for state in existing.values where !currentSet.contains(state.filePath) {
            try store.deleteChunks(projectPath: projectPath, filePath: state.filePath)
            try store.deleteFileState(projectPath: projectPath, filePath: state.filePath)
        }

        let fileCount = try store.countProjectFiles(projectPath: projectPath)
        let chunkCount = try store.countProjectChunks(projectPath: projectPath)
        try store.upsertProjectIndexState(
            projectPath: projectPath,
            fileCount: fileCount,
            chunkCount: chunkCount,
            embeddingModel: embeddingProvider.modelIdentifierWithVersion,
            embeddingDimension: embeddingProvider.dimension
        )
        stats.chunkCount = chunkCount
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)增量索引结束 scanned=\(stats.scannedFiles) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) fileCount=\(fileCount) chunkCount=\(chunkCount)"
            )
        }
        return stats
    }

    // MARK: - Private

    private func indexFiles(
        _ files: [String],
        projectPath: String,
        background: Bool,
        shouldContinue: @escaping @Sendable () -> Bool
    ) async throws -> RAGIndexStats {
        let existingStates = try store.fetchIndexedFileStates(projectPath: projectPath)
        var stats = RAGIndexStats()

        for filePath in files {
            try Task.checkCancellation()
            if background, (Task.isCancelled || !shouldContinue()) {
                throw CancellationError()
            }
            stats.scannedFiles += 1
            guard let fileAttr = try? FileManager.default.attributesOfItem(atPath: filePath),
                  let modifiedDate = fileAttr[.modificationDate] as? Date else {
                stats.skippedFiles += 1
                logProgressIfNeeded(stats: stats, total: files.count, currentFilePath: filePath, projectPath: projectPath)
                continue
            }

            let modifiedTime = modifiedDate.timeIntervalSince1970
            if let indexed = existingStates[filePath], abs(indexed.modifiedTime - modifiedTime) < 0.001 {
                stats.skippedFiles += 1
                logProgressIfNeeded(stats: stats, total: files.count, currentFilePath: filePath, projectPath: projectPath)
                continue
            }

            guard let content = try? RAGTextFileReader.read(path: filePath),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                stats.skippedFiles += 1
                logProgressIfNeeded(stats: stats, total: files.count, currentFilePath: filePath, projectPath: projectPath)
                continue
            }

            let contentHash = RAGSQLiteStore.contentHash(content)
            if let indexed = existingStates[filePath], indexed.contentHash == contentHash {
                try store.upsertFileStateOnly(
                    projectPath: projectPath,
                    filePath: filePath,
                    modifiedTime: modifiedTime,
                    contentHash: contentHash
                )
                stats.skippedFiles += 1
                logProgressIfNeeded(stats: stats, total: files.count, currentFilePath: filePath, projectPath: projectPath)
                continue
            }

            let chunks = chunker.chunk(content)
            if background {
                guard shouldContinue() else { throw CancellationError() }
                try Task.checkCancellation()
            }
            let embeddings = try embeddingProvider.embedBatch(chunks.map(\.content))
            if background {
                guard shouldContinue() else { throw CancellationError() }
                try Task.checkCancellation()
            }
            try store.replaceFileChunks(
                projectPath: projectPath,
                filePath: filePath,
                modifiedTime: modifiedTime,
                contentHash: contentHash,
                chunks: chunks,
                embeddings: embeddings,
                embeddingDimension: embeddingProvider.dimension
            )

            stats.indexedFiles += 1
            stats.chunkCount += chunks.count
            logProgressIfNeeded(stats: stats, total: files.count, currentFilePath: filePath, projectPath: projectPath)

            // 向量化是 CPU 密集且内部多核并行的操作。连续处理多个文件会让
            // 当前协作线程长期霸占 CPU，导致主 actor 调度延迟上升（实测主线程
            // 事件循环间隔从 50ms 尖刺到 150ms）。让出时间片把 CPU 归还给前台。
            await Task.yield()
        }

        return stats
    }

    private func logProgressIfNeeded(stats: RAGIndexStats, total: Int, currentFilePath: String, projectPath: String) {
        guard stats.scannedFiles % Self.progressLogInterval == 0 || stats.scannedFiles == total else { return }
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)进度 \(stats.scannedFiles)/\(total) indexed=\(stats.indexedFiles) skipped=\(stats.skippedFiles) chunks=\(stats.chunkCount) file=\(currentFilePath)"
            )
        }
        let event = RAGIndexProgressEvent(
            projectPath: projectPath,
            scannedFiles: stats.scannedFiles,
            totalFiles: total,
            indexedFiles: stats.indexedFiles,
            skippedFiles: stats.skippedFiles,
            chunkCount: stats.chunkCount,
            currentFilePath: currentFilePath,
            isFinished: stats.scannedFiles == total
        )
        onProgress?(event)
    }
}
