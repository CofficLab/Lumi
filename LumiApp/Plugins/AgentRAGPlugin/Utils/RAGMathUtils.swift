import Foundation
import Accelerate

enum RAGMathUtils {
    /// 计算余弦相似度
    /// - Parameters:
    ///   - a: 向量A
    ///   - b: 向量B
    /// - Returns: 相似度（0-1之间）
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let magA = sqrt(a.reduce(Float(0)) { $0 + $1 * $1 })
        let magB = sqrt(b.reduce(Float(0)) { $0 + $1 * $1 })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }
}
