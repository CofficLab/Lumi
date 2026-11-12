import Foundation
@testable import PluginProjectRAG
import KitAgentTool
import ProjectRAGEngine
import ProviderProjectRAG
import Testing

@MainActor
private final class ContractStubProvider: ProjectRAGProviding {
    var currentProjectPath: String?
    let isInitialized = true
    var lastTopK: Int?

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        lastTopK = topK
        return ProjectRAGResponse(query: query, results: [])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? { nil }
}

@Suite("RAGCodeSearchToolContract", .serialized)
@MainActor
struct RAGCodeSearchToolContractTests {
    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-contract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("missing query throws")
    func missingQueryThrows() async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await RAGCodeSearchTool().execute(arguments: [:])
        }
    }

    @Test("missing project throws")
    func missingProjectThrows() async {
        ProjectRAGRuntime.reset()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await RAGCodeSearchTool().execute(arguments: ["query": ToolArgument("handleRequest")])
        }
    }

    @Test("nonexistent path throws")
    func nonexistentPathThrows() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-missing-\(UUID().uuidString)").path
        do {
            _ = try await RAGCodeSearchTool().execute(arguments: [
                "query": ToolArgument("handleRequest"),
                "project_path": ToolArgument(missing),
            ])
            Issue.record("expected ToolExecutionError")
        } catch let error as ToolExecutionError {
            guard case let .executionFailed(_, reason) = error else {
                Issue.record("unexpected case: \(error)")
                return
            }
            #expect(reason.contains(missing))
        }
    }

    @Test("unavailable provider throws")
    func unavailableProviderThrows() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        ProjectRAGRuntime.reset()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await RAGCodeSearchTool().execute(arguments: [
                "query": ToolArgument("handleRequest"),
                "project_path": ToolArgument(dir.path),
            ])
        }
    }

    @Test("top_k is clamped to the schema range")
    func topKClampedToSchemaRange() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let provider = ContractStubProvider()
        let tool = RAGCodeSearchTool(provider: provider)

        _ = try await tool.execute(arguments: [
            "query": ToolArgument("x"), "project_path": ToolArgument(dir.path), "top_k": ToolArgument(-5),
        ])
        #expect(provider.lastTopK == 1)

        _ = try await tool.execute(arguments: [
            "query": ToolArgument("x"), "project_path": ToolArgument(dir.path), "top_k": ToolArgument(999),
        ])
        #expect(provider.lastTopK == 20)

        _ = try await tool.execute(arguments: [
            "query": ToolArgument("x"), "project_path": ToolArgument(dir.path), "top_k": ToolArgument("abc"),
        ])
        #expect(provider.lastTopK == 8)
    }

    @Test("empty result returns an informational string")
    func emptyResultReturnsInformationalString() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let output = try await RAGCodeSearchTool(provider: ContractStubProvider()).execute(arguments: [
            "query": ToolArgument("nothingMatches"), "project_path": ToolArgument(dir.path),
        ])
        #expect(output.contains("No code matched"))
        #expect(!output.contains("Error"))
    }
}