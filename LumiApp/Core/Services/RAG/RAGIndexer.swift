import Foundation

struct RAGIndexer {
    private static let skipDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData", "Pods", "Carthage", "node_modules", "dist", "build"
    ]

    private static let allowedExtensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp",
        "js", "ts", "tsx", "jsx", "json", "yml", "yaml", "toml",
        "md", "txt", "rst", "py", "rb", "go", "rs", "java", "kt",
        "sql", "html", "css", "scss", "xml", "sh", "zsh"
    ]

    private let store: RAGSQLiteStore
    private let chunker: RAGChunker
    private let embeddingModelId: String
    private let embeddingDimension: Int

    init(store: RAGSQLiteStore, embeddingModelId: String, embeddingDimension: Int) {
        self.store = store
        self.chunker = RAGChunker()
        self.embeddingModelId = embeddingModelId
        self.embeddingDimension = embeddingDimension
    }

    func rebuildProjectIndex(at projectPath: String) throws -> RAGIndexStats {
        let files = discoverFiles(in: projectPath)
        let indexedStates = try store.fetchIndexedFileStates(projectPath: projectPath)

        for state in indexedStates.values {
            try store.deleteChunks(projectPath: projectPath, filePath: state.filePath)
            try store.deleteFileState(projectPath: projectPath, filePath: state.filePath)
        }

        var stats = try indexFiles(files, projectPath: projectPath)
        let fileCount = try store.countProjectFiles(projectPath: projectPath)
        let chunkCount = try store.countProjectChunks(projectPath: projectPath)
        try store.upsertProjectIndexState(
            projectPath: projectPath,
            fileCount: fileCount,
            chunkCount: chunkCount,
            embeddingModel: embeddingModelId,
            embeddingDimension: embeddingDimension
        )
        stats.chunkCount = chunkCount
        return stats
    }

    func indexProjectIncrementally(at projectPath: String) throws -> RAGIndexStats {
        let files = discoverFiles(in: projectPath)
        var stats = try indexFiles(files, projectPath: projectPath)

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
            embeddingModel: embeddingModelId,
            embeddingDimension: embeddingDimension
        )
        stats.chunkCount = chunkCount
        return stats
    }

    private func indexFiles(_ files: [String], projectPath: String) throws -> RAGIndexStats {
        let existingStates = try store.fetchIndexedFileStates(projectPath: projectPath)
        var stats = RAGIndexStats()

        for filePath in files {
            stats.scannedFiles += 1
            guard let fileAttr = try? FileManager.default.attributesOfItem(atPath: filePath),
                  let modifiedDate = fileAttr[.modificationDate] as? Date else {
                stats.skippedFiles += 1
                continue
            }

            let modifiedTime = modifiedDate.timeIntervalSince1970
            if let indexed = existingStates[filePath], abs(indexed.modifiedTime - modifiedTime) < 0.001 {
                stats.skippedFiles += 1
                continue
            }

            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                stats.skippedFiles += 1
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
                continue
            }

            let chunks = chunker.chunk(content)
            try store.replaceFileChunks(
                projectPath: projectPath,
                filePath: filePath,
                modifiedTime: modifiedTime,
                contentHash: contentHash,
                chunks: chunks,
                embeddingDimension: embeddingDimension
            )

            stats.indexedFiles += 1
            stats.chunkCount += chunks.count
        }

        return stats
    }

    private func discoverFiles(in projectPath: String) -> [String] {
        let rootURL = URL(fileURLWithPath: projectPath)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []
        let maxFileSizeBytes = 1_500_000

        for case let url as URL in enumerator {
            let path = url.path
            if shouldSkipPath(path) {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            let ext = url.pathExtension.lowercased()
            guard Self.allowedExtensions.contains(ext) else { continue }
            if let size = values.fileSize, size > maxFileSizeBytes { continue }

            files.append(path)
        }

        return files
    }

    private func shouldSkipPath(_ path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        for component in components where Self.skipDirectories.contains(component) {
            return true
        }
        return false
    }
}
