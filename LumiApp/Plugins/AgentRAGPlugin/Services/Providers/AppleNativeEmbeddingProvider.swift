import Foundation
import NaturalLanguage

/// Apple 原生向量化提供者
/// 使用系统内置的 NaturalLanguage 框架进行向量化
struct AppleNativeEmbeddingProvider: RAGEmbeddingProvider {
    let modelID: String
    let modelVersion: String
    let dimension: Int
    private let hashFallback: HashEmbeddingProvider

    init(modelID: String = "apple-nl-proj", modelVersion: String = "v1", dimension: Int = 384) {
        let dim = max(dimension, 8)
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = dim
        self.hashFallback = HashEmbeddingProvider(modelID: "local-hash", modelVersion: "v1", dimension: dim)
    }

    func embed(_ text: String) throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [Float](repeating: 0, count: dimension) }

        // 尝试使用 Apple 原生引擎
        if let raw = rawVector(for: trimmed), !raw.isEmpty {
            return projectedNormalized(raw: raw, dimension: dimension)
        }
        
        // 降级到哈希方案
        return try hashFallback.embed(trimmed)
    }

    // MARK: - Private Methods

    /// 使用 Apple NaturalLanguage 框架生成原始向量
    private func rawVector(for text: String) -> [Double]? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let detected = recognizer.dominantLanguage

        // 候选语言列表
        var candidates: [NLLanguage] = []
        if let detected {
            candidates.append(detected)
        }
        candidates.append(contentsOf: [.english, .simplifiedChinese, .traditionalChinese])

        // 尝试使用不同语言的模型
        var seen = Set<NLLanguage>()
        for lang in candidates where seen.insert(lang).inserted {
            // 优先使用句子级 embedding
            if let sentenceModel = NLEmbedding.sentenceEmbedding(for: lang),
               let vector = sentenceModel.vector(for: text) {
                return convertToDoubleArray(vector)
            }
            
            // 降级使用词级 embedding
            if let wordModel = NLEmbedding.wordEmbedding(for: lang),
               let vector = wordModel.vector(for: text) {
                return convertToDoubleArray(vector)
            }
        }
        return nil
    }

    /// 转换 Double 数组
    private func convertToDoubleArray(_ vector: [Double]) -> [Double] {
        vector
    }

    /// 转换 Float 数组到 Double
    private func convertToDoubleArray(_ vector: [Float]) -> [Double] {
        vector.map { Double($0) }
    }

    /// 投影并归一化向量到指定维度
    private func projectedNormalized(raw: [Double], dimension: Int) -> [Float] {
        var output = [Float](repeating: 0, count: dimension)
        
        // 使用伪随机投影将原始向量映射到目标维度
        for (index, value) in raw.enumerated() {
            let bucket = index % dimension
            let sign: Float = ((index &* 1103515245 &+ 12345) & 1) == 0 ? 1 : -1
            output[bucket] += Float(value) * sign
        }

        // L2 归一化
        let norm = sqrt(output.reduce(Float(0)) { $0 + $1 * $1 })
        guard norm > 0 else { return output }
        return output.map { $0 / norm }
    }
}
