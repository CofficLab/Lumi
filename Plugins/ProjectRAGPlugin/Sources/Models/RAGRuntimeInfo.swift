import Foundation

/// RAG 运行时信息
public struct RAGRuntimeInfo: Sendable {
    public let vectorBackend: RAGVectorBackend
    public let sqliteVecPath: String?
    public let note: String?

    public init(
        vectorBackend: RAGVectorBackend,
        sqliteVecPath: String? = nil,
        note: String? = nil
    ) {
        self.vectorBackend = vectorBackend
        self.sqliteVecPath = sqliteVecPath
        self.note = note
    }
}

/// RAG 触发判断结果
public struct RAGIntentDecision: Sendable {
    public let shouldUseRAG: Bool
    public let score: Double
    public let threshold: Double
    public let reasons: [String]

    public init(shouldUseRAG: Bool, score: Double, threshold: Double, reasons: [String]) {
        self.shouldUseRAG = shouldUseRAG
        self.score = score
        self.threshold = threshold
        self.reasons = reasons
    }
}
