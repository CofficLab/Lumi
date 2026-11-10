import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 回归 #1118：硬阈值请求等待的预热摘要可能因为请求期间产生新消息而作废。
/// 等待方不能把这次过期结果当成压缩已完成，必须按最新历史重试。
@MainActor
struct StalePrewarmSummaryRetryTests {

    @Test("等待过期预热摘要后按最新历史重试", .timeLimit(.minutes(1)))
    func hardThresholdRetriesAfterDiscardedPrewarm() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = GatedSummaryProvider(contextWindowTokens: 20_000)
        try llm.register(summaryProvider)
        llm.select(
            providerID: summaryProvider.providerID,
            model: "summary-model",
            reason: .userSelected
        )

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<60 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 600) + "\(index)"
                ),
                to: conversationID
            )
        }

        // 回合完成后的预热摘要：第一次摘要请求被挂住，模拟接口尚未返回。
        provider.scheduleBackgroundCompaction(for: conversationID)
        try await summaryProvider.waitUntilFirstRequestStarts()
        #expect(summaryProvider.completeCalls == 1)

        // 预热请求仍挂起时用户发送下一回合，使预热结果的水位立即过旧。
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "下一回合内容 ", count: 600)
            ),
            to: conversationID
        )

        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: LLMContextBudget(
                contextWindowTokens: 20_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )

        let preparation = Task { await provider.prepareContext(for: request) }
        // 留出时间让硬阈值路径进入 ensureCompaction 并等待同一个摘要任务。
        try await Task.sleep(for: .milliseconds(300))
        summaryProvider.releaseFirstRequest()
        let result = await preparation.value

        // 过期预热被丢弃后必须按最新历史重新生成一次摘要，而不是直接降级。
        #expect(summaryProvider.completeCalls == 2)
        #expect(result.didCompact)
        #expect(!result.didFallback)
        #expect(result.messages.contains { $0.metadata["llmContext"] == "summary" })
    }
}

@MainActor
private final class GatedSummaryProvider: SuperLLMProvider {
    let providerInfo: LLMProviderInfo
    private(set) var completeCalls = 0
    private var firstRequestContinuation: CheckedContinuation<Void, Never>?
    private var firstRequestStarted = false

    init(contextWindowTokens: Int) {
        providerInfo = LLMProviderInfo(
            id: "gated-summary-provider",
            displayName: "Gated Summary Provider",
            defaultModel: "summary-model",
            models: [LLMModelInfo(id: "summary-model", contextWindowSize: contextWindowTokens)]
        )
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        completeCalls += 1
        if completeCalls == 1 {
            firstRequestStarted = true
            await withCheckedContinuation { continuation in
                firstRequestContinuation = continuation
            }
        }
        return LLMResponse(content: "摘要结果", model: request.model)
    }

    func waitUntilFirstRequestStarts() async throws {
        while !firstRequestStarted {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func releaseFirstRequest() {
        firstRequestContinuation?.resume()
        firstRequestContinuation = nil
    }
}
