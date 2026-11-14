import Foundation
@testable import PluginProjectRAG
import KitAgentTool
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderProjectRAG
import Testing

/// 回归 #467：自动注入的重复检索抑制标记只含 projectPath+query+time，跨对话共享。
/// 对话 A 注入后，对话 B 紧接着的同项目同查询真实 search_code 会消费 A 的标记，
/// 被误判为「证据已注入当前上下文」而跳过真实检索。抑制记录必须绑定 conversationID。
@Suite("ProjectRAGSearchMemoryConversation")
@MainActor
struct ProjectRAGSearchMemoryConversationTests {
    @Test("同一对话的同查询重复检索被抑制")
    func suppressesSameConversationDuplicate() {
        let memory = ProjectRAGSearchMemory()
        let conversation = UUID()
        memory.recordAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: conversation)

        #expect(memory.consumeRecentAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: conversation))
    }

    @Test("另一对话不得消费抑制标记，原对话仍可消费（回归 #467）")
    func doesNotSuppressAcrossConversations() {
        let memory = ProjectRAGSearchMemory()
        let a = UUID()
        let b = UUID()
        memory.recordAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: a)

        #expect(!memory.consumeRecentAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: b),
                "B 不得消费 A 的抑制标记")
        #expect(memory.consumeRecentAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: a),
                "标记仍留给真正注入证据的 A")
    }

    @Test("无对话上下文的旧入口不得消费已绑定对话的标记（回归 #467）")
    func legacyNilConversationDoesNotConsumeBoundMarker() {
        let memory = ProjectRAGSearchMemory()
        let a = UUID()
        memory.recordAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: a)

        #expect(!memory.consumeRecentAutomaticSearch(query: "Q", projectPath: "/tmp/P", conversationID: nil))
    }
}

@MainActor
private final class CountingProvider: ProjectRAGProviding {
    var currentProjectPath: String?
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

@Suite("ProjectRAGCrossConversationSuppression")
@MainActor
struct ProjectRAGCrossConversationSuppressionTests {
    @Test("对话 A 注入后，对话 B 的同查询真实检索不被跳过（回归 #467）")
    func conversationBSearchIsNotSuppressedByA() async throws {
        let provider = CountingProvider()
        let searchMemory = ProjectRAGSearchMemory()
        let hook = ProjectRAGLLMContextHook(provider: provider, searchMemory: searchMemory)
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-cross-conv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }
        provider.currentProjectPath = projectURL.path

        let query = "这个项目的代码怎么实现请求处理"
        let conversationA = UUID()
        let conversationB = UUID()
        _ = await hook.apply(to: WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: query)],
            conversationID: conversationA
        ))
        #expect(provider.searchCallCount == 1)

        // B 在 2s 内发起同项目同查询的真实 search_code：不得消费 A 的抑制标记。
        let toolContext = ToolExecutionContext(jobID: "job-B", conversationID: conversationB)
        let output = try await RAGCodeSearchTool(provider: provider, searchMemory: searchMemory)
            .executeResult(context: toolContext, arguments: [
                "query": ToolArgument(query),
                "project_path": ToolArgument(projectURL.path),
            ]).content

        #expect(!output.contains("already injected"), "B 的真实检索不得被误判为已注入")
        #expect(output.contains("Sources/Feature.swift"))
        #expect(provider.searchCallCount == 2, "B 必须真正执行检索")
    }
}