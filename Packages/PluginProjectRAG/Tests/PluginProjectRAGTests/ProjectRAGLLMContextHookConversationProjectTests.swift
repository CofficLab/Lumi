import Foundation
@testable import PluginProjectRAG
import KitLLM
import ProjectRAGEngine
import ProviderConversation
import ProviderLifecycleHooks
import ProviderProjectRAG
import Testing

@MainActor
private final class RecordingProvider: ProjectRAGProviding {
    var currentProjectPath: String?
    let isInitialized = true
    private(set) var searchCallCount = 0
    private(set) var lastSearchProjectPath: String?

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        searchCallCount += 1
        lastSearchProjectPath = projectPath
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

/// 回归 #603：自动 RAG 注入读全局 currentProjectPath，外部打开切换全局项目后，
/// 仍选中的旧对话会检索并注入另一个项目的代码。检索必须作用于请求所属对话绑定的
/// 项目；无法确定对话项目时不注入，绝不静默回退到可能无关的全局项目。
@Suite("ProjectRAGLLMContextHookConversationProject")
@MainActor
struct ProjectRAGLLMContextHookConversationProjectTests {
    private let userText = "这个项目的代码怎么实现请求处理"

    private func makeContext(_ conversationID: UUID) -> WillSendToLLMContext {
        WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: userText)],
            conversationID: conversationID
        )
    }

    @Test("检索使用对话绑定的项目 A，而非全局当前项目 B（回归 #603）")
    func usesConversationProjectNotGlobalCurrent() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "Bound to A", projectPath: "/tmp/A", providerID: nil, modelName: nil
        )
        let provider = RecordingProvider()
        provider.currentProjectPath = "/tmp/B"
        let hook = ProjectRAGLLMContextHook(provider: provider, conversations: conversations)

        let result = await hook.apply(to: makeContext(conversationID))

        #expect(provider.lastSearchProjectPath == "/tmp/A")
        #expect(result.messages.contains { $0.role == .system && $0.content.contains("Project code navigation context:") })
    }

    @Test("对话未绑定项目时不注入，也不回退到全局当前项目（回归 #603）")
    func skipsWhenConversationUnboundEvenIfGlobalSet() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "Unbound", projectPath: nil, providerID: nil, modelName: nil
        )
        let provider = RecordingProvider()
        provider.currentProjectPath = "/tmp/B"
        let hook = ProjectRAGLLMContextHook(provider: provider, conversations: conversations)
        let context = makeContext(conversationID)

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
        #expect(provider.searchCallCount == 0, "不得静默回退到全局项目检索")
    }

    @Test("对话项目路径两侧空白被裁剪后再检索（回归 #603）")
    func trimsConversationProjectPath() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "Padded", projectPath: "  /tmp/A  ", providerID: nil, modelName: nil
        )
        let provider = RecordingProvider()
        provider.currentProjectPath = "/tmp/B"
        let hook = ProjectRAGLLMContextHook(provider: provider, conversations: conversations)

        _ = await hook.apply(to: makeContext(conversationID))

        #expect(provider.lastSearchProjectPath == "/tmp/A")
    }
}