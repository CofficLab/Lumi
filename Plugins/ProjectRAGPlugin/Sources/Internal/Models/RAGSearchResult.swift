import Foundation

/// RAG 检索结果
public struct RAGSearchResult: Sendable {
    public let content: String
    public let source: String
    public let score: Float

    public init(content: String, source: String, score: Float) {
        self.content = content
        self.source = source
        self.score = score
    }
}

/// RAG 响应
public struct RAGResponse: Sendable {
    public let query: String
    public let results: [RAGSearchResult]

    public init(query: String, results: [RAGSearchResult]) {
        self.query = query
        self.results = results
    }

    public var hasResults: Bool { !results.isEmpty }
}
