import Testing
import ProviderProjectRAG

@Suite("ProjectRAG Provider Contract")
struct ProjectRAGProvidingTests {
    @Test("response keeps query and result order")
    func responseIsSendableValue() {
        let response = ProjectRAGResponse(
            query: "kernel",
            results: [ProjectRAGSearchResult(content: "registerProvider", source: "Kernel.swift", score: 0.9)]
        )

        #expect(response.query == "kernel")
        #expect(response.results.count == 1)
        #expect(response.results[0].source == "Kernel.swift")
    }
}
