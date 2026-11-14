import Foundation
@testable import PluginProjectRAG
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderProjectRAG
import Testing

@MainActor
private final class EvidenceStubProvider: ProjectRAGProviding {
    var currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true
    private(set) var searchCallCount = 0

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        searchCallCount += 1
        return ProjectRAGResponse(query: query, results: [
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

/// 回归 #604：自动 RAG 证据只插进单次请求的局部消息副本，而工具调用后历史重建、
/// 去重键（会话 + 用户消息数 + 最新用户正文）不变，导致后续请求直接早退、证据消失。
/// 同一用户回合的后续请求必须复用已检索证据，直到该回合结束。
@Suite("ProjectRAGLLMContextHookEvidenceReuse")
@MainActor
struct ProjectRAGLLMContextHookEvidenceReuseTests {
    private let userText = "这个项目的代码怎么实现请求处理"
    private let evidencePrefix = "Project code navigation context:"

    private func evidenceMessages(_ messages: [LLMMessage]) -> [LLMMessage] {
        messages.filter { $0.role == .system && $0.content.hasPrefix(evidencePrefix) }
    }

    @Test("工具调用后历史重建，同一回合的后续请求仍含已检索证据且不重复检索（回归 #604）")
    func evidenceReusedAfterToolCallRebuild() async {
        let provider = EvidenceStubProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let conversationID = UUID()

        let first = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: userText)],
            conversationID: conversationID
        )
        let firstResult = await hook.apply(to: first)
        #expect(evidenceMessages(firstResult.messages).count == 1)
        #expect(provider.searchCallCount == 1)

        // 工具调用后历史重建：注入的系统消息只存在于上次请求的局部副本，未被持久化，
        // 这里只剩 user + assistant(tool call) + tool(result)，用户消息数与正文不变。
        let rebuilt = WillSendToLLMContext(
            messages: [
                LLMMessage(role: .user, content: userText),
                LLMMessage(role: .assistant, content: "calling search_code"),
                LLMMessage(role: .tool, content: "tool result"),
            ],
            conversationID: conversationID
        )
        let secondResult = await hook.apply(to: rebuilt)
        #expect(evidenceMessages(secondResult.messages).count == 1, "后续请求必须复用证据，不得消失")
        #expect(provider.searchCallCount == 1, "复用缓存证据不应再次检索")
    }

    @Test("历史已持久化证据时复用不得重复插入（回归 #604）")
    func evidenceNotDuplicatedWhenAlreadyPersisted() async {
        let provider = EvidenceStubProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let conversationID = UUID()

        let first = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: userText)],
            conversationID: conversationID
        )
        let firstResult = await hook.apply(to: first)
        #expect(evidenceMessages(firstResult.messages).count == 1)

        // 这次历史里已经带着上次注入的系统消息。
        var persisted = firstResult.messages
        persisted.append(LLMMessage(role: .assistant, content: "answer"))
        let again = WillSendToLLMContext(messages: persisted, conversationID: conversationID)
        let result = await hook.apply(to: again)
        #expect(evidenceMessages(result.messages).count == 1, "已存在的证据不得被重复插入")
    }

    @Test("新的用户消息触发新一轮检索，不复用旧回合证据（回归 #604）")
    func newUserMessageTriggersFreshSearch() async {
        let provider = EvidenceStubProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let conversationID = UUID()

        let first = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: userText)],
            conversationID: conversationID
        )
        _ = await hook.apply(to: first)
        #expect(provider.searchCallCount == 1)

        let nextTurn = WillSendToLLMContext(
            messages: [
                LLMMessage(role: .user, content: userText),
                LLMMessage(role: .assistant, content: "answer"),
                LLMMessage(role: .user, content: "这个项目的代码怎么实现错误重试"),
            ],
            conversationID: conversationID
        )
        let result = await hook.apply(to: nextTurn)
        #expect(provider.searchCallCount == 2, "新用户消息应触发新检索")
        #expect(evidenceMessages(result.messages).count == 1)
    }
}