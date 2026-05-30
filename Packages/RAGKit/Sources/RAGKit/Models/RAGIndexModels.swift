import Foundation

/// RAG 已索引文件状态
public struct RAGIndexedFileState: Sendable {
    public let filePath: String
    public let modifiedTime: Double
    public let contentHash: String

    public init(filePath: String, modifiedTime: Double, contentHash: String) {
        self.filePath = filePath
        self.modifiedTime = modifiedTime
        self.contentHash = contentHash
    }
}

/// RAG 索引统计
public struct RAGIndexStats: Sendable {
    public var scannedFiles: Int
    public var indexedFiles: Int
    public var skippedFiles: Int
    public var chunkCount: Int

    public init(
        scannedFiles: Int = 0,
        indexedFiles: Int = 0,
        skippedFiles: Int = 0,
        chunkCount: Int = 0
    ) {
        self.scannedFiles = scannedFiles
        self.indexedFiles = indexedFiles
        self.skippedFiles = skippedFiles
        self.chunkCount = chunkCount
    }
}

/// RAG 项目索引状态（数据库持久化）
public struct RAGProjectIndexState: Sendable {
    public let projectPath: String
    public let lastIndexedAt: Double
    public let fileCount: Int
    public let chunkCount: Int
    public let embeddingModel: String
    public let embeddingDimension: Int

    public init(
        projectPath: String,
        lastIndexedAt: Double,
        fileCount: Int,
        chunkCount: Int,
        embeddingModel: String,
        embeddingDimension: Int
    ) {
        self.projectPath = projectPath
        self.lastIndexedAt = lastIndexedAt
        self.fileCount = fileCount
        self.chunkCount = chunkCount
        self.embeddingModel = embeddingModel
        self.embeddingDimension = embeddingDimension
    }
}

/// RAG 索引状态（面向 UI 展示）
public struct RAGIndexStatus: Sendable {
    public let projectPath: String
    public let lastIndexedAt: Date
    public let fileCount: Int
    public let chunkCount: Int
    public let embeddingModel: String
    public let embeddingDimension: Int
    public let isStale: Bool

    public init(
        projectPath: String,
        lastIndexedAt: Date,
        fileCount: Int,
        chunkCount: Int,
        embeddingModel: String,
        embeddingDimension: Int,
        isStale: Bool
    ) {
        self.projectPath = projectPath
        self.lastIndexedAt = lastIndexedAt
        self.fileCount = fileCount
        self.chunkCount = chunkCount
        self.embeddingModel = embeddingModel
        self.embeddingDimension = embeddingDimension
        self.isStale = isStale
    }
}

/// RAG 索引进度事件
public struct RAGIndexProgressEvent: Sendable {
    public let projectPath: String
    public let scannedFiles: Int
    public let totalFiles: Int
    public let indexedFiles: Int
    public let skippedFiles: Int
    public let chunkCount: Int
    public let currentFilePath: String
    public let isFinished: Bool

    public init(
        projectPath: String,
        scannedFiles: Int,
        totalFiles: Int,
        indexedFiles: Int,
        skippedFiles: Int,
        chunkCount: Int,
        currentFilePath: String,
        isFinished: Bool
    ) {
        self.projectPath = projectPath
        self.scannedFiles = scannedFiles
        self.totalFiles = totalFiles
        self.indexedFiles = indexedFiles
        self.skippedFiles = skippedFiles
        self.chunkCount = chunkCount
        self.currentFilePath = currentFilePath
        self.isFinished = isFinished
    }
}
