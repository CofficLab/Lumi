import Foundation

/// RAG 检索结果
struct RAGSearchResult {
    let content: String
    let source: String
    let score: Float
}

/// RAG 响应
struct RAGResponse {
    let query: String
    let results: [RAGSearchResult]

    var hasResults: Bool { !results.isEmpty }
}

struct RAGChunk {
    let index: Int
    let content: String
}

struct RAGStoredChunk {
    let id: Int64
    let content: String
    let filePath: String
    let embedding: [Float]
}

struct RAGVectorMatch {
    let chunkId: Int64
    let distance: Float
}

struct RAGIndexedFileState {
    let filePath: String
    let modifiedTime: Double
    let contentHash: String
}

struct RAGIndexStats {
    var scannedFiles: Int = 0
    var indexedFiles: Int = 0
    var skippedFiles: Int = 0
    var chunkCount: Int = 0
}

struct RAGProjectIndexState {
    let projectPath: String
    let lastIndexedAt: Double
    let fileCount: Int
    let chunkCount: Int
    let embeddingModel: String
    let embeddingDimension: Int
}

struct RAGIndexStatus {
    let projectPath: String
    let lastIndexedAt: Date
    let fileCount: Int
    let chunkCount: Int
    let embeddingModel: String
    let embeddingDimension: Int
    let isStale: Bool
}

enum RAGVectorBackend: String {
    case swiftCosine = "swift-cosine"
    case sqliteVec = "sqlite-vec"
}

struct RAGRuntimeInfo {
    let vectorBackend: RAGVectorBackend
    let sqliteVecPath: String?
    let note: String?
}

/// RAG 触发判断结果
struct RAGIntentDecision {
    let shouldUseRAG: Bool
    let score: Double
    let threshold: Double
    let reasons: [String]
}
