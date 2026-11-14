import Foundation

/// Swift BM25（Task 2.1b'）：内置 SQLite 无 FTS5，索引词法候选在内存打分。
/// df 只在候选集内统计（候选上限 1000/2500），k1=1.2、b=0.75。
public enum RAGBM25 {
    static let k1 = 1.2
    static let b = 0.75

    /// 返回与 documents 对齐的 BM25 得分；查询词为空时全 0。
    public static func scores(queryTerms: [String], documents: [String]) -> [Double] {
        let terms = Array(Set(queryTerms.map { $0.lowercased() })).filter { !$0.isEmpty }
        guard !terms.isEmpty, !documents.isEmpty else {
            return Array(repeating: 0, count: documents.count)
        }

        let tokenized = documents.map { RAGTextUtils.tokenize($0.lowercased()) }
        let lengths = tokenized.map { Double($0.count) }
        let averageLength = lengths.reduce(0, +) / Double(lengths.count)
        let total = Double(documents.count)

        var documentFrequency: [String: Int] = [:]
        var termFrequencies: [[String: Int]] = []
        termFrequencies.reserveCapacity(tokenized.count)
        for tokens in tokenized {
            var frequencies: [String: Int] = [:]
            for token in tokens {
                frequencies[token, default: 0] += 1
            }
            for term in terms where frequencies[term] != nil {
                documentFrequency[term, default: 0] += 1
            }
            termFrequencies.append(frequencies)
        }

        var inverseDocumentFrequency: [String: Double] = [:]
        for term in terms {
            let df = Double(documentFrequency[term] ?? 0)
            inverseDocumentFrequency[term] = log(1 + (total - df + 0.5) / (df + 0.5))
        }

        return termFrequencies.enumerated().map { index, frequencies in
            let lengthNorm = k1 * (1 - b + b * lengths[index] / max(averageLength, 1))
            var score = 0.0
            for term in terms {
                let tf = Double(frequencies[term] ?? 0)
                guard tf > 0 else { continue }
                score += (inverseDocumentFrequency[term] ?? 0) * (tf * (k1 + 1)) / (tf + lengthNorm)
            }
            return score
        }
    }
}