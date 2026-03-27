import CryptoKit
import Foundation
import NaturalLanguage

protocol RAGEmbeddingProvider {
    var modelID: String { get }
    var modelVersion: String { get }
    var dimension: Int { get }

    func embed(_ text: String) throws -> [Float]
    func embedBatch(_ texts: [String]) throws -> [[Float]]
}

extension RAGEmbeddingProvider {
    var modelIdentifierWithVersion: String {
        "\(modelID)@\(modelVersion)"
    }

    func embedBatch(_ texts: [String]) throws -> [[Float]] {
        try texts.map(embed)
    }
}

enum RAGEmbeddingFactory {
    static func makeProvider() -> RAGEmbeddingProvider {
        // 简化策略：不再读取环境变量，固定使用 App 内原生 embedding。
        // 若原生向量不可用，AppleNativeEmbeddingProvider 内部会自动回退到 hash。
        return AppleNativeEmbeddingProvider(dimension: 384)
    }
}

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

    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

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

        if let raw = rawVector(for: trimmed), !raw.isEmpty {
            return projectedNormalized(raw: raw, dimension: dimension)
        }
        return try hashFallback.embed(trimmed)
    }

    private func rawVector(for text: String) -> [Double]? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let detected = recognizer.dominantLanguage

        var candidates: [NLLanguage] = []
        if let detected {
            candidates.append(detected)
        }
        candidates.append(contentsOf: [.english, .simplifiedChinese, .traditionalChinese])

        var seen = Set<NLLanguage>()
        for lang in candidates where seen.insert(lang).inserted {
            if let sentenceModel = NLEmbedding.sentenceEmbedding(for: lang),
               let vector = sentenceModel.vector(for: text) {
                return convertToDoubleArray(vector)
            }
            if let wordModel = NLEmbedding.wordEmbedding(for: lang),
               let vector = wordModel.vector(for: text) {
                return convertToDoubleArray(vector)
            }
        }
        return nil
    }

    private func convertToDoubleArray(_ vector: [Double]) -> [Double] {
        vector
    }

    private func convertToDoubleArray(_ vector: [Float]) -> [Double] {
        vector.map { Double($0) }
    }

    private func projectedNormalized(raw: [Double], dimension: Int) -> [Float] {
        var output = [Float](repeating: 0, count: dimension)
        for (index, value) in raw.enumerated() {
            let bucket = index % dimension
            let sign: Float = ((index &* 1103515245 &+ 12345) & 1) == 0 ? 1 : -1
            output[bucket] += Float(value) * sign
        }

        let norm = sqrt(output.reduce(Float(0)) { $0 + $1 * $1 })
        guard norm > 0 else { return output }
        return output.map { $0 / norm }
    }
}

extension UnicodeScalar {
    var isCJK: Bool {
        switch value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF:
            return true
        default:
            return false
        }
    }
}
