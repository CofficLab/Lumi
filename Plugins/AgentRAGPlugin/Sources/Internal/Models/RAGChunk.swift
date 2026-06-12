import Foundation

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
