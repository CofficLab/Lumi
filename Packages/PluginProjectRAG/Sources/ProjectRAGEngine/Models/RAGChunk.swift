import Foundation

public struct RAGLineRange: Sendable, Equatable {
    public let startLine: Int
    public let endLine: Int

    public init(startLine: Int, endLine: Int) {
        self.startLine = max(startLine, 1)
        self.endLine = max(self.startLine, endLine)
    }
}

/// RAG 文本块
public struct RAGChunk: Sendable {
    public let index: Int
    public let content: String
    public let lineRange: RAGLineRange?

    public init(index: Int, content: String, lineRange: RAGLineRange?) {
        self.index = index
        self.content = content
        self.lineRange = lineRange
    }

    public init(index: Int, content: String) {
        self.init(index: index, content: content, lineRange: nil)
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
