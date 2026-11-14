import Foundation
import ProjectRAGEngine
import Testing

@Suite("RAGContextBuilderBudget")
struct RAGContextBuilderBudgetTests {
    private let estimator: (String) -> Int = { text in
        max(Int(ceil(Double(text.utf8.count) / 3.0)), 1)
    }

    private func makeResults(count: Int) -> [RAGSearchResult] {
        (0..<count).map { index in
            RAGSearchResult(
                content: String(repeating: "a", count: 300) + " marker\(index) end",
                source: "Sources/File\(index).swift",
                score: 0.9,
                matchKind: .semantic
            )
        }
    }

    @Test("prompt fits the token budget and keeps snippets whole")
    func promptFitsTokenBudget() throws {
        let prompt = try #require(RAGContextBuilder.buildPrompt(
            query: "q",
            results: makeResults(count: 10),
            projectPath: "/tmp/project",
            languagePreference: .english,
            maxTokens: 600,
            tokenEstimator: estimator
        ))

        #expect(estimator(prompt) <= 600)
        let retained = (0..<10).filter { prompt.contains("marker\($0) end") }
        #expect(!retained.isEmpty)
        #expect(retained.count < 10)
        for index in retained {
            #expect(prompt.contains(String(repeating: "a", count: 300) + " marker\(index) end"))
        }
        #expect(!prompt.contains("...[truncated]"))
    }

    @Test("nil budget keeps the legacy character limit")
    func nilBudgetKeepsLegacyCharLimit() throws {
        let results = (0..<6).map { index in
            RAGSearchResult(
                content: String(repeating: "b", count: 4000),
                source: "Sources/B\(index).swift",
                score: 0.8
            )
        }
        let prompt = try #require(RAGContextBuilder.buildPrompt(
            query: "q",
            results: results,
            projectPath: nil,
            languagePreference: .english
        ))

        #expect(prompt.count < 11000)
        #expect(prompt.contains("...[truncated]"))
    }

    @Test("tiny budget drops all snippets and skips injection")
    func tinyBudgetDropsAllSnippets() {
        let prompt = RAGContextBuilder.buildPrompt(
            query: "q",
            results: makeResults(count: 3),
            projectPath: "/tmp/project",
            languagePreference: .english,
            maxTokens: 10,
            tokenEstimator: estimator
        )

        #expect(prompt == nil)
    }
}