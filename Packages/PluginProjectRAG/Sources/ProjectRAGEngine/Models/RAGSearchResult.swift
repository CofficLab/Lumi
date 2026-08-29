import Foundation

/// 检索结果的证据来源。
public enum RAGMatchKind: String, Sendable, Equatable {
    case semantic
    case indexedLexical
    case filesystemLexical
}

public struct RAGLineRange: Sendable, Equatable {
    public let startLine: Int
    public let endLine: Int

    public init(startLine: Int, endLine: Int) {
        self.startLine = startLine
        self.endLine = max(startLine, endLine)
    }
}

/// RAG 检索结果
public struct RAGSearchResult: Sendable {
    public let content: String
    public let source: String
    public let score: Float
    public let matchKind: RAGMatchKind
    public let lineRange: RAGLineRange?

    public init(
        content: String,
        source: String,
        score: Float,
        matchKind: RAGMatchKind,
        lineRange: RAGLineRange?
    ) {
        self.content = content
        self.source = source
        self.score = score
        self.matchKind = matchKind
        self.lineRange = lineRange
    }

    public init(content: String, source: String, score: Float, matchKind: RAGMatchKind) {
        self.init(content: content, source: source, score: score, matchKind: matchKind, lineRange: nil)
    }

    public init(content: String, source: String, score: Float) {
        self.init(content: content, source: source, score: score, matchKind: .semantic, lineRange: nil)
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
