import CryptoKit
import Foundation

/// 哈希向量化提供者
/// 使用 SHA256 哈希算法将文本转换为向量，作为备用方案
struct HashEmbeddingProvider: RAGEmbeddingProvider {
    let modelID: String
    let modelVersion: String
    let dimension: Int

    init(modelID: String = "local-hash", modelVersion: String = "v1", dimension: Int = 256) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = max(dimension, 8)
    }

    func embed(_ text: String) throws -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        let normalized = text.lowercased()
        let tokens = tokenize(normalized)

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

    /// 文本分词
    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var buffer = ""

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if !buffer.isEmpty {
                tokens.append(buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if scalar.isCJK {
                tokens.append(String(scalar))
            }
        }

        if !buffer.isEmpty {
            tokens.append(buffer)
        }
        return tokens
    }

    /// 向量归一化
    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

// MARK: - UnicodeScalar Extension

extension UnicodeScalar {
    /// 是否为中日韩（CJK）字符
    var isCJK: Bool {
        switch value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF:
            return true
        default:
            return false
        }
    }
}
