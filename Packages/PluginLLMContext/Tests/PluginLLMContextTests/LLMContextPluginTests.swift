import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

@MainActor
struct LLMContextPluginTests {
    @Test("短会话透传完整历史")
    func shortConversationUsesFullHistory() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "你好"),
            to: conversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.count == 1)
        #expect(result[0].content == "你好")
    }

    @Test("摘要生成失败时不阻塞，继续返回完整历史")
    func summaryFailureFallsBackToFullHistory() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()

        for index in 0..<LLMContextProvider.compactionMessageThreshold + 1 {
            messages.insertMessage(
                Message(conversationID: conversationID, role: .user, content: "消息 \(index)"),
                to: conversationID
            )
        }

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.count == LLMContextProvider.compactionMessageThreshold + 1)
    }

    @Test("生成摘要时使用防提示注入的摘要指令")
    func summaryPromptTreatsConversationAsData() {
        #expect(LLMContextProvider.summarySystemPrompt.contains("untrusted data"))
        #expect(LLMContextProvider.summarySystemPrompt.contains("Do not invent facts"))
    }

    @Test("后台生成摘要后返回摘要和最近消息")
    func backgroundSummaryCompactsHistory() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model")

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            messages.insertMessage(
                Message(conversationID: conversationID, role: .user, content: "消息 \(index)"),
                to: conversationID
            )
        }

        // 第一次请求不等待摘要，触发后台刷新。
        let initial = await provider.messagesForLLM(in: conversationID)
        #expect(initial.count == LLMContextProvider.compactionMessageThreshold + 1)

        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 100_000_000)
            let compacted = await provider.messagesForLLM(in: conversationID)
            if compacted.contains(where: { $0.metadata["llmContext"] == "summary" }) {
                #expect(compacted.count < initial.count)
                #expect(compacted.contains { $0.content.contains("摘要结果") })
                #expect(summaryProvider.completeCalls == 1)
                return
            }
        }

        #expect(Bool(false), "后台摘要未在测试窗口内生成")
    }

    @Test("重新创建 Provider 后复用磁盘摘要")
    func persistedSummarySurvivesProviderRecreation() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMContextStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = try ContextSummaryStore(directory: directory)
        let conversationID = UUID()
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            messages.insertMessage(
                Message(conversationID: conversationID, role: .user, content: "消息 \(index)"),
                to: conversationID
            )
        }

        let firstProvider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            summaryStore: store
        )
        _ = await firstProvider.messagesForLLM(in: conversationID)

        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 100_000_000)
            let result = await firstProvider.messagesForLLM(in: conversationID)
            if result.contains(where: { $0.metadata["llmContext"] == "summary" }) {
                break
            }
        }

        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(ContextSummaryStore.databaseFileName).path
        ))
        #expect(summaryProvider.completeCalls == 1)

        let secondProvider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            summaryStore: store
        )
        let restored = await secondProvider.messagesForLLM(in: conversationID)

        #expect(restored.contains { $0.metadata["llmContext"] == "summary" })
        #expect(restored.contains { $0.content.contains("摘要结果") })
        #expect(summaryProvider.completeCalls == 1)
    }
}

@MainActor
private final class SummaryLLMProvider: SuperLLMProvider {
    let providerInfo = LLMProviderInfo(
        id: "summary-test-provider",
        displayName: "Summary Test Provider",
        defaultModel: "summary-model",
        models: [LLMModelInfo(id: "summary-model")]
    )
    private(set) var completeCalls = 0

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        completeCalls += 1
        return LLMResponse(content: "摘要结果", model: request.model)
    }
}
