import Foundation

/// RAG 检索结果
public struct RAGSearchResult: Sendable {
    public let content: String
    public let source: String
    public let score: Float

    public init(content: String, source: String, score: Float) {
        self.content = content
        self.source = source
        self.score = score
    }
}

/// RAG 响应
public struct RAGResponse: Sendable {
    public let query: String
    public let results: [RAGSearchResult]

    public init(query: String, results: [RAGSearchResult]) {
        self.query = query
        self.results = results
    }

    public var hasResults: Bool { !results.isEmpty }
}

/// RAG 文本块
public struct RAGChunk: Sendable {
    public let index: Int
    public let content: String

    public init(index: Int, content: String) {
        self.index = index
        self.content = content
    }
}

/// RAG 存储块（含向量和元数据）
public struct RAGStoredChunk: Sendable {
    public let id: Int64
    public let content: String
    public let filePath: String
    public let embedding: [Float]

    public init(id: Int64, content: String, filePath: String, embedding: [Float]) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.embedding = embedding
    }
}

/// RAG 向量匹配结果
public struct RAGVectorMatch: Sendable {
    public let chunkId: Int64
    public let distance: Float

    public init(chunkId: Int64, distance: Float) {
        self.chunkId = chunkId
        self.distance = distance
    }
}

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

/// 向量后端类型
public enum RAGVectorBackend: String, Sendable {
    case swiftCosine = "swift-cosine"
    case sqliteVec = "sqlite-vec"
}

/// RAG 运行时信息
public struct RAGRuntimeInfo: Sendable {
    public let vectorBackend: RAGVectorBackend
    public let sqliteVecPath: String?
    public let note: String?

    public init(
        vectorBackend: RAGVectorBackend,
        sqliteVecPath: String? = nil,
        note: String? = nil
    ) {
        self.vectorBackend = vectorBackend
        self.sqliteVecPath = sqliteVecPath
        self.note = note
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

/// RAG 触发判断结果
public struct RAGIntentDecision: Sendable {
    public let shouldUseRAG: Bool
    public let score: Double
    public let threshold: Double
    public let reasons: [String]

    public init(shouldUseRAG: Bool, score: Double, threshold: Double, reasons: [String]) {
        self.shouldUseRAG = shouldUseRAG
        self.score = score
        self.threshold = threshold
        self.reasons = reasons
    }
}
