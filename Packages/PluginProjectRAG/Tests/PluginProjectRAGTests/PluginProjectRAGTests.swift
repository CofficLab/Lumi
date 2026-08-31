import Foundation
@testable import PluginProjectRAG
import KernelCore
import KitAgentTool
import KitLLM
import ProviderLifecycleHooks
import ProviderProjectRAG
import Testing

@Suite("ProjectRAGSuperPlugin")
@MainActor
struct ProjectRAGSuperPluginTests {
    @Test("keeps the legacy plugin and tool identifiers")
    func retainsStableIdentifiers() {
        #expect(ProjectRAGSuperPlugin().id == "com.coffic.lumi.plugin.project.rag")
        #expect(RAGCodeSearchTool.toolName == "search_code")
    }

    @Test("registers the RAG capability in KernelCore")
    func registersProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = ProjectRAGSuperPlugin()

        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectRAGProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectRAGProviding).self) == nil)
    }
}

@MainActor
private final class StubProjectRAGProvider: ProjectRAGProviding {
    var currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true
    var indexing = false
    var ensureIndexedCallCount = 0
    var lastEnsureIndexedBackground: Bool?
    var searchCallCount = 0
    var response = ProjectRAGResponse(
        query: "",
        results: [
            ProjectRAGSearchResult(
                content: "func handleRequest() {}",
                source: "Sources/Feature.swift",
                score: 0.9,
                matchKind: .semantic,
                lineRange: ProjectRAGLineRange(startLine: 12, endLine: 19)
            ),
        ]
    )

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func isIndexing(projectPath: String) -> Bool {
        indexing
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        searchCallCount += 1
        return response
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        ensureIndexedCallCount += 1
        lastEnsureIndexedBackground = background
    }

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        nil
    }
}

@Suite("ProjectRAGLLMContextHook")
@MainActor
struct ProjectRAGLLMContextHookTests {
    @Test("injects code context once for one user message")
    func injectsContextOnce() async {
        let provider = StubProjectRAGProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "这个项目的代码怎么实现请求处理")],
            conversationID: UUID()
        )

        let first = await hook.apply(to: context)
        let second = await hook.apply(to: context)
        let otherContext = WillSendToLLMContext(
            messages: context.messages,
            conversationID: UUID()
        )
        let other = await hook.apply(to: otherContext)

        #expect(first.messages.count == context.messages.count + 1)
        #expect(first.messages.first?.role == .system)
        #expect(first.messages.first?.content.contains("Sources/Feature.swift:12-19") == true)
        #expect(second.messages.count == context.messages.count)
        #expect(other.messages.count == otherContext.messages.count + 1)
        #expect(provider.ensureIndexedCallCount == 2)
        #expect(provider.lastEnsureIndexedBackground == false)
    }

    @Test("does not query RAG for casual conversation")
    func skipsCasualConversation() async {
        let provider = StubProjectRAGProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "hello, how are you today")],
            conversationID: UUID()
        )

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
        #expect(provider.ensureIndexedCallCount == 0)
    }

    @Test("does not wait for RAG while the project is indexing")
    func skipsIndexingProject() async {
        let provider = StubProjectRAGProvider()
        provider.indexing = true
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "了解这个项目的代码")],
            conversationID: UUID()
        )

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
        #expect(provider.ensureIndexedCallCount == 0)
        #expect(provider.searchCallCount == 0)
    }
}

@Suite("RAGCodeSearchTool")
@MainActor
struct RAGCodeSearchToolTests {
    @Test("includes line evidence in tool output")
    func includesLineEvidence() async throws {
        let provider = StubProjectRAGProvider()
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-tool-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let output = try await RAGCodeSearchTool(provider: provider).execute(arguments: [
            "query": ToolArgument("handleRequest"),
            "project_path": ToolArgument(projectURL.path),
        ])

        #expect(output.contains("Sources/Feature.swift:12-19"))
        #expect(output.contains("evidence: semantic"))
        #expect(output.contains("func handleRequest() {}"))
    }

    @Test("suppresses an immediate duplicate after automatic injection")
    func suppressesImmediateDuplicate() async throws {
        let provider = StubProjectRAGProvider()
        let searchMemory = ProjectRAGSearchMemory()
        let hook = ProjectRAGLLMContextHook(provider: provider, searchMemory: searchMemory)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "这个项目的代码怎么实现请求处理")],
            conversationID: UUID()
        )
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-tool-dedup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }
        provider.currentProjectPath = projectURL.path

        _ = await hook.apply(to: context)
        let output = try await RAGCodeSearchTool(provider: provider, searchMemory: searchMemory).execute(arguments: [
            "query": ToolArgument("这个项目的代码怎么实现请求处理"),
            "project_path": ToolArgument(projectURL.path),
        ])

        #expect(output.contains("already injected"))
        #expect(provider.searchCallCount == 1)
    }
}

@Suite("CodeNavigationCoordinator")
@MainActor
struct CodeNavigationCoordinatorTests {
    @Test("does not enqueue semantic search while indexing")
    func skipsSemanticSearchDuringIndexing() async throws {
        let provider = StubProjectRAGProvider()
        provider.indexing = true
        let coordinator = CodeNavigationCoordinator(provider: provider)

        let response = try await coordinator.search(
            query: "了解这个项目的代码",
            projectPath: "/tmp/Lumi",
            topK: 8
        )

        #expect(response.query == "了解这个项目的代码")
        #expect(response.results.isEmpty)
        #expect(provider.ensureIndexedCallCount == 0)
        #expect(provider.searchCallCount == 0)
    }

    @Test("indexes a missing project before searching")
    func indexesMissingProjectBeforeSearching() async throws {
        let provider = StubProjectRAGProvider()
        let coordinator = CodeNavigationCoordinator(provider: provider)

        let response = try await coordinator.search(
            query: "handleRequest",
            projectPath: "/tmp/Lumi",
            topK: 8
        )

        #expect(response.results.count == 1)
        #expect(provider.ensureIndexedCallCount == 1)
        #expect(provider.lastEnsureIndexedBackground == false)
        #expect(provider.searchCallCount == 1)
    }

    @Test("merges semantic and exact file evidence")
    func mergesSemanticAndExactFileEvidence() async throws {
        let provider = StubProjectRAGProvider()
        let coordinator = CodeNavigationCoordinator(provider: provider)
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-coordinator-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = projectURL.appendingPathComponent("Sources/Router.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "func routeRequest() {}".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let response = try await coordinator.search(
            query: "routeRequest",
            projectPath: projectURL.path,
            topK: 8
        )

        #expect(response.results.contains { result in
            result.source == "Sources/Router.swift" && result.matchKind == .filesystemLexical
        })
    }

    @Test("merges explicit file path evidence")
    func mergesExplicitFilePathEvidence() async throws {
        let provider = StubProjectRAGProvider()
        let coordinator = CodeNavigationCoordinator(provider: provider)
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-coordinator-path-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = projectURL.appendingPathComponent("Sources/Router.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "let unrelatedValue = true".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let response = try await coordinator.search(
            query: "Sources/Router.swift",
            projectPath: projectURL.path,
            topK: 8
        )

        #expect(response.results.contains { result in
            result.source == "Sources/Router.swift" && result.matchKind == .filesystemPath
        })
    }
}
