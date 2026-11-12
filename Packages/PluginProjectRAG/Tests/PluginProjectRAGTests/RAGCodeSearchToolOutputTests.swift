import Foundation
@testable import PluginProjectRAG
import KitAgentTool
import ProviderProjectRAG
import Testing

@MainActor
private final class OutputStubProvider: ProjectRAGProviding {
    var currentProjectPath: String?
    let isInitialized = true
    let stubResults: [ProjectRAGSearchResult]

    init(results: [ProjectRAGSearchResult]) {
        self.stubResults = results
    }

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        ProjectRAGResponse(query: query, results: stubResults)
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? { nil }
}

@Suite("RAGCodeSearchToolOutput", .serialized)
@MainActor
struct RAGCodeSearchToolOutputTests {

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func execute(provider: OutputStubProvider, dir: URL) async throws -> String {
        try await RAGCodeSearchTool(provider: provider).execute(arguments: [
            "query": ToolArgument("needle"),
            "project_path": ToolArgument(dir.path),
        ])
    }

    @Test("output budget truncates with marker")
    func searchCodeOutputBudgetTruncates() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bulky = (0..<20).map { index in
            ProjectRAGSearchResult(
                content: "marker\(index) " + String(repeating: "a", count: 2990),
                source: "Sources/F\(index).swift",
                score: 0.9,
                matchKind: .semantic,
                lineRange: ProjectRAGLineRange(startLine: 1, endLine: 50)
            )
        }

        let output = try await execute(provider: OutputStubProvider(results: bulky), dir: dir)
        #expect(output.utf8.count <= 20_000)
        #expect(output.contains("[truncated:"))
        #expect(output.contains("grep"))
    }

    @Test("single snippet clipped at 3000 characters")
    func searchCodeSnippetClippedAt3000() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let huge = [ProjectRAGSearchResult(
            content: String(repeating: "a", count: 5000),
            source: "Sources/Huge.swift",
            score: 0.9,
            matchKind: .semantic,
            lineRange: ProjectRAGLineRange(startLine: 1, endLine: 200)
        )]

        let output = try await execute(provider: OutputStubProvider(results: huge), dir: dir)
        #expect(!output.contains(String(repeating: "a", count: 3001)))
        #expect(output.contains("[snippet clipped]"))
    }

    @Test("header shows evidence mix")
    func searchCodeHeaderShowsEvidenceMix() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mixed = [
            ProjectRAGSearchResult(content: "s", source: "S.swift", score: 0.9, matchKind: .semantic),
            ProjectRAGSearchResult(content: "l", source: "L.swift", score: 0.8, matchKind: .filesystemLexical),
            ProjectRAGSearchResult(content: "p", source: "P.swift", score: 0.7, matchKind: .filesystemPath),
        ]

        let output = try await execute(provider: OutputStubProvider(results: mixed), dir: dir)
        #expect(output.contains("semantic: 1, live-lexical: 1, path: 1"))
    }
}