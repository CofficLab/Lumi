import Foundation
@testable import PluginProjectRAG
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderProjectRAG
import Testing

@MainActor
private final class PositionStubProvider: ProjectRAGProviding {
    var currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true

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
                score: 0.9,
                matchKind: .semantic,
                lineRange: ProjectRAGLineRange(startLine: 12, endLine: 19)
            ),
        ])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? { nil }
}

@Suite("ProjectRAGLLMContextHookPosition")
@MainActor
struct ProjectRAGLLMContextHookPositionTests {
    private let codeQuestion = "这个项目的代码怎么实现请求处理"

    @Test("injection preserves the history prefix")
    func injectionPreservesHistoryPrefix() async {
        let hook = ProjectRAGLLMContextHook(provider: PositionStubProvider())
        let history = [
            LLMMessage(role: .system, content: "base system"),
            LLMMessage(role: .user, content: "earlier question"),
            LLMMessage(role: .assistant, content: "earlier answer"),
            LLMMessage(role: .user, content: codeQuestion),
        ]
        let context = WillSendToLLMContext(messages: history, conversationID: UUID())

        let result = await hook.apply(to: context)

        #expect(result.messages.count == history.count + 1)
        #expect(Array(result.messages[0..<3]) == Array(history[0..<3]))
        #expect(result.messages[3].role == .system)
        #expect(result.messages[3].content.contains("Sources/Feature.swift"))
        #expect(result.messages[4] == history[3])
    }

    @Test("injection anchors on the latest user even with a trailing system message")
    func injectionBeforeLatestUserWhenTrailingSystemExists() async {
        let hook = ProjectRAGLLMContextHook(provider: PositionStubProvider())
        let history = [
            LLMMessage(role: .user, content: "earlier question"),
            LLMMessage(role: .assistant, content: "earlier answer"),
            LLMMessage(role: .user, content: codeQuestion),
            LLMMessage(role: .system, content: "trailing system"),
        ]
        let context = WillSendToLLMContext(messages: history, conversationID: UUID())

        let result = await hook.apply(to: context)

        #expect(result.messages.count == history.count + 1)
        #expect(result.messages[2].role == .system)
        #expect(result.messages[2].content.contains("Sources/Feature.swift"))
        #expect(result.messages[3] == history[2])
        #expect(result.messages[4] == history[3])
    }
}