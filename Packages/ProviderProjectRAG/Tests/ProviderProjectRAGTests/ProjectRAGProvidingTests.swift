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

    @Test("line range clamps end to at least start")
    func lineRangeClampsEndBelowStart() {
        let range = ProjectRAGLineRange(startLine: 10, endLine: 3)
        #expect(range.startLine == 10)
        #expect(range.endLine == 10)

        let valid = ProjectRAGLineRange(startLine: 3, endLine: 10)
        #expect(valid.startLine == 3)
        #expect(valid.endLine == 10)
    }

    @Test("search result defaults to semantic kind and no range")
    func searchResultConvenienceDefaults() {
        let result = ProjectRAGSearchResult(
            content: "body",
            source: "File.swift",
            score: 0.5
        )
        #expect(result.matchKind == .semantic)
        #expect(result.lineRange == nil)

        let withKind = ProjectRAGSearchResult(
            content: "body",
            source: "File.swift",
            score: 0.5,
            matchKind: .filesystemPath
        )
        #expect(withKind.matchKind == .filesystemPath)
        #expect(withKind.lineRange == nil)
    }
}
