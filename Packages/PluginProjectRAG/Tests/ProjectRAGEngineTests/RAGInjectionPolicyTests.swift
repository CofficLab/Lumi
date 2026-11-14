import Foundation
import ProjectRAGEngine
import Testing

@Suite("RAGInjectionPolicy")
struct RAGInjectionPolicyTests {
    @Test("semantic score below threshold does not inject")
    func semanticBelowThresholdDoesNotInject() {
        let results = [RAGSearchResult(content: "x", source: "A.swift", score: 0.49, matchKind: .semantic)]
        #expect(RAGInjectionPolicy.shouldInject(results: results) == false)
    }

    @Test("semantic score at threshold injects")
    func semanticAtThresholdInjects() {
        let results = [RAGSearchResult(content: "x", source: "A.swift", score: 0.50, matchKind: .semantic)]
        #expect(RAGInjectionPolicy.shouldInject(results: results) == true)
    }

    @Test("two lexical hits inject")
    func twoLexicalHitsInject() {
        let results = [
            RAGSearchResult(content: "x", source: "A.swift", score: 0.1, matchKind: .filesystemLexical),
            RAGSearchResult(content: "y", source: "B.swift", score: 0.1, matchKind: .indexedLexical),
        ]
        #expect(RAGInjectionPolicy.shouldInject(results: results) == true)
    }

    @Test("single lexical hit does not inject")
    func singleLexicalHitDoesNotInject() {
        let results = [RAGSearchResult(content: "x", source: "A.swift", score: 0.1, matchKind: .filesystemLexical)]
        #expect(RAGInjectionPolicy.shouldInject(results: results) == false)
    }
}