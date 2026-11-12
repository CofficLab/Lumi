import Foundation
@testable import PluginProjectRAG
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderProjectRAG
import Testing

@MainActor
private final class BudgetStubProvider: ProjectRAGProviding {
    var currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        ProjectRAGResponse(query: query, results: (0..<10).map { index in
            ProjectRAGSearchResult(
                content: String(repeating: "a", count: 300) + " marker\(index) end",
                source: "Sources/F\(index).swift",
                score: 0.9,
                matchKind: .semantic,
                lineRange: ProjectRAGLineRange(startLine: 1, endLine: 5)
            )
        })
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? { nil }
}

@Suite("ProjectRAGLLMContextHookBudget")
@MainActor
struct ProjectRAGLLMContextHookBudgetTests {
    private func makeContext(budget: Int?) -> WillSendToLLMContext {
        WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "这个项目的代码怎么实现请求处理")],
            conversationID: UUID(),
            injectedContentTokenBudget: budget
        )
    }

    @Test("hook skips injection when the budget is zero")
    func hookSkipsInjectionWhenBudgetZero() async {
        let hook = ProjectRAGLLMContextHook(provider: BudgetStubProvider())
        let context = makeContext(budget: 0)

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
    }

    @Test("hook honors the injected content budget")
    func hookHonorsInjectedContentBudget() async throws {
        let hook = ProjectRAGLLMContextHook(provider: BudgetStubProvider())
        let context = makeContext(budget: 600)

        let result = await hook.apply(to: context)

        #expect(result.messages.count == context.messages.count + 1)
        let injected = try #require(result.messages.first { $0.role == .system })
        #expect(LLMContextTokenEstimator.estimate(text: injected.content) <= 600)
    }
}