import CryptoKit
import Foundation

/// 哈希向量化提供者（用于测试和开发环境的伪 embedding）
/// 使用 SHA256 哈希算法将文本转换为向量，不产生真实语义嵌入
public struct MockEmbeddingProvider: RAGEmbeddingProvider, Sendable {
    public let modelID: String
    public let modelVersion: String
    public let dimension: Int

    public init(modelID: String = "local-hash", modelVersion: String = "v1", dimension: Int = 256) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = max(dimension, 8)
    }

    public func embed(_ text: String) throws -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        let normalized = text.lowercased()
        let tokens = RAGTextUtils.tokenize(normalized)

        if tokens.isEmpty { return vector }

        for token in tokens {
            let digest = SHA256.hash(data: Data(token.utf8))
            let bytes = Array(digest)
            if bytes.count < 2 { continue }

            let index = Int(bytes[0]) % dimension
            let sign: Float = (bytes[1] & 1) == 0 ? 1 : -1
            vector[index] += sign
        }

        return normalize(vector)
    }

    // MARK: - Private Methods

    /// 向量归一化
    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

/// 向后兼容别名
@available(*, deprecated, renamed: "MockEmbeddingProvider")
public typealias HashEmbeddingProvider = MockEmbeddingProvider
