import Accelerate
import Foundation

public enum RAGMathUtils {
    /// 计算余弦相似度
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let magA = sqrt(a.reduce(Float(0)) { $0 + $1 * $1 })
        let magB = sqrt(b.reduce(Float(0)) { $0 + $1 * $1 })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }
}
