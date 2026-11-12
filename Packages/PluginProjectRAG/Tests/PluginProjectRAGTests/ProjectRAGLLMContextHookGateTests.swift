import Foundation
@testable import PluginProjectRAG
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderProjectRAG
import Testing

@MainActor
private final class GateStubProvider: ProjectRAGProviding {
    var currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true
    var semanticScore: Float = 0.9

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        ProjectRAGResponse(query: query, results: [
            ProjectRAGSearchResult(
                content: "func handleRequest() {}",
                source: "Sources/Feature.swift",
                score: semanticScore,
                matchKind: .semantic,
                lineRange: ProjectRAGLineRange(startLine: 12, endLine: 19)
            ),
        ])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? { nil }
}

@Suite("ProjectRAGLLMContextHookGate")
@MainActor
struct ProjectRAGLLMContextHookGateTests {
    private func makeContext() -> WillSendToLLMContext {
        WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "这个项目的代码怎么实现请求处理")],
            conversationID: UUID()
        )
    }

    @Test("disabled toggle skips injection")
    func hookToggleDisabledSkipsInjection() async {
        let suite = "rag-toggle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(false, forKey: RAGInjectionPolicy.autoInjectEnabledKey)
        defer { defaults.removePersistentDomain(forName: suite) }

        let hook = ProjectRAGLLMContextHook(provider: GateStubProvider(), defaults: defaults)
        let context = makeContext()

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
    }

    @Test("low confidence results skip injection")
    func lowConfidenceResultsSkipInjection() async {
        let provider = GateStubProvider()
        provider.semanticScore = 0.40
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = makeContext()

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
    }
}