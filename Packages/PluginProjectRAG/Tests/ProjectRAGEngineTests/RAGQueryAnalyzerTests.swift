import Foundation
import Testing
@testable import ProjectRAGEngine

/// 自然语言 → 搜索词：标识符/文件名优先，CJK 去停用词，空结果回退旧分词。
@Suite struct RAGQueryAnalyzerTests {

    @Test func chineseDesignQuestionExtractsDomainTerm() {
        let terms = RAGQueryAnalyzer.extractTerms(query: "登录功能是怎么设计的")
        #expect(terms.contains("登录"))
        #expect(!terms.contains("怎么"))
        #expect(!terms.contains("功能"))
        #expect(!terms.contains("设计"))
    }

    @Test func identifierPreserved() {
        let terms = RAGQueryAnalyzer.extractTerms(query: "Where is LoginViewController defined")
        #expect(terms.contains("LoginViewController"))
        #expect(!terms.contains("Where"))
        #expect(!terms.contains("where"))
        #expect(!terms.contains("defined"))
    }

    @Test func fileNamePreserved() {
        let terms = RAGQueryAnalyzer.extractTerms(query: "打开 Package.swift 看看")
        #expect(terms.contains("Package.swift"))
    }

    @Test func emptyExtractionFallsBackToTokenize() {
        let query = "hello world"
        #expect(RAGQueryAnalyzer.extractTerms(query: query) == RAGTextUtils.tokenize(query))
    }

    @Test func termCapAtEight() {
        let identifiers = (0..<10).map { "Symbol\($0)Name" }
        let terms = RAGQueryAnalyzer.extractTerms(query: identifiers.joined(separator: " "))
        #expect(terms.count == 8)
        #expect(terms == Array(identifiers.prefix(8)))
    }

    @Test func priorityOrderIdentifierThenFileNameThenCJK() {
        let terms = RAGQueryAnalyzer.extractTerms(query: "登录 Package.swift LoginViewController")
        #expect(terms == ["LoginViewController", "Package.swift", "登录"])
    }

    @Test func snakeCaseAndDigitsQualifyAsIdentifiers() {
        let terms = RAGQueryAnalyzer.extractTerms(query: "user_id 和 abc123 在哪")
        #expect(terms.contains("user_id"))
        #expect(terms.contains("abc123"))
    }
}