import Foundation

/// RAG 向量匹配结果
public struct RAGVectorMatch: Sendable {
    public let chunkId: Int64
    public let distance: Float

    public init(chunkId: Int64, distance: Float) {
        self.chunkId = chunkId
        self.distance = distance
    }
}

/// 向量后端类型
public enum RAGVectorBackend: String, Sendable {
    case swiftCosine = "swift-cosine"
    case sqliteVec = "sqlite-vec"
}
