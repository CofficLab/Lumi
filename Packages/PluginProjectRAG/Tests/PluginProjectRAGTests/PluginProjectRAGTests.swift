@testable import PluginProjectRAG
import KernelCore
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
    let currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true
    var ensureIndexedCallCount = 0
    var response = ProjectRAGResponse(
        query: "",
        results: [
            ProjectRAGSearchResult(
                content: "func handleRequest() {}",
                source: "Sources/Feature.swift",
                score: 0.9
            ),
        ]
    )

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        response
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        ensureIndexedCallCount += 1
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

        #expect(first.messages.count == context.messages.count + 1)
        #expect(first.messages.first?.role == .system)
        #expect(second.messages.count == context.messages.count)
        #expect(provider.ensureIndexedCallCount == 1)
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
}
