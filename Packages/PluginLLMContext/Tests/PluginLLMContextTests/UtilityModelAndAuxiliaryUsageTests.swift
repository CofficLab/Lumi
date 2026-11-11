import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 可配置的路由摘要供应商：声明轻量模型、记录服务模型、可注入用量或失败。
@MainActor
private final class RoutingSummaryProvider: SuperLLMProvider {
    let providerInfo: LLMProviderInfo
    var availableModels: [LLMModelInfo]

    private(set) var servedModels: [String] = []
    private(set) var lastRequest: LLMRequest?
    var completeCalls: Int { servedModels.count }

    /// 非 nil 时响应携带上报用量；nil 时不报用量（触发估算口径）。
    var reportedUsage: (input: Int, output: Int)?
    /// 置 true 时轻量模型调用抛错，用于验证回退主模型。
    var failUtility = false
    var summaryText = "摘要结果"

    init(
        id: String = "routing-provider",
        recommendedUtilityModel: String? = "utility-model",
        mainContextWindow: Int = 200_000,
        utilityContextWindow: Int = 16_000
    ) {
        let models = [
            LLMModelInfo(id: "main-model", contextWindowSize: mainContextWindow),
            LLMModelInfo(id: "main-model-2", contextWindowSize: mainContextWindow),
            LLMModelInfo(id: "utility-model", contextWindowSize: utilityContextWindow),
        ]
        providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: "main-model",
            models: models,
            recommendedUtilityModel: recommendedUtilityModel
        )
        availableModels = models
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let model = request.model ?? ""
        servedModels.append(model)
        lastRequest = request
        if failUtility, model == "utility-model" {
            throw RoutingTestError.utilityFailed
        }
        if let reportedUsage {
            return LLMResponse(
                content: summaryText,
                model: model,
                inputTokenCount: reportedUsage.input,
                outputTokenCount: reportedUsage.output
            )
        }
        return LLMResponse(content: summaryText, model: model)
    }
}

private enum RoutingTestError: Error {
    case utilityFailed
}

/// 纯内存幕后账本替身，记录写入供断言。
@MainActor
private final class InMemoryAuxiliaryLedger: LLMAuxiliaryUsageProviding {
    private(set) var recorded: [LLMAuxiliaryUsageEntry] = []

    func record(_ entry: LLMAuxiliaryUsageEntry) async {
        recorded.append(entry)
    }

    func entries(for conversationID: UUID) async -> [LLMAuxiliaryUsageEntry] {
        recorded.filter { $0.conversationID == conversationID }
    }
}

/// #1157 轻量模型路由 + #1158 幕后用量账本的回归测试。
@MainActor
struct UtilityModelAndAuxiliaryUsageTests {

    // MARK: - Helpers

    private func makeLongHistory(_ messages: DefaultMessageManager, conversationID: UUID, count: Int = 60) {
        for index in 0..<count {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 600) + "\(index)"
                ),
                to: conversationID
            )
        }
    }

    private func compactionRequest(conversationID: UUID, providerID: String) -> LLMContextPreparationRequest {
        LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: providerID,
            model: "main-model",
            budget: LLMContextBudget(
                contextWindowTokens: 20_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )
    }

    private func firstCompactionEvent(_ messages: DefaultMessageManager, conversationID: UUID) -> Message? {
        messages.messages(for: conversationID).first { MessageTimelineEvent.isActualContextCompaction($0) }
    }

    // MARK: - #1157 Routing

    @Test("摘要路由到供应商声明的轻量模型")
    func summaryRoutesToUtilityModel() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider()
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let ledger = InMemoryAuxiliaryLedger()
        let context = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            auxiliaryUsage: ledger
        )
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        let result = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        #expect(result.didCompact)
        #expect(provider.servedModels == ["utility-model"])
        let event = try #require(firstCompactionEvent(messages, conversationID: conversationID))
        #expect(event.metadata[MessageTimelineEvent.contextCompactionSummaryModelNameKey] == "utility-model")
        #expect(event.metadata[MessageTimelineEvent.contextCompactionSummaryProviderIDKey] == provider.providerID)
    }

    @Test("未声明轻量模型时摘要仍走主模型")
    func summaryFallsBackToMainWithoutDeclaration() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider(recommendedUtilityModel: nil)
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let context = LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm)
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        let result = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        #expect(result.didCompact)
        #expect(provider.servedModels == ["main-model"])
    }

    @Test("摘要输入受轻量模型窗口约束")
    func summaryInputBoundedByUtilityWindow() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider(utilityContextWindow: 16_000)
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let context = LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm)
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        _ = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        let request = try #require(provider.lastRequest)
        let inputEstimate = request.messages.reduce(0) {
            $0 + LLMContextTokenEstimator.estimate(text: $1.content) + LLMContextProvider.messageOverheadTokens
        }
        // 摘要输入必须装进轻量模型窗口（16K），而不是主模型的输入预算（17K）。
        // 历史部分按轻量预算收缩，系统提示叠加其上，总量仍远小于主模型预算。
        let utilityWindow = 16_000
        #expect(inputEstimate <= utilityWindow)
        #expect(inputEstimate < 17_000)
    }

    @Test("切换对话主模型不作废轻量模型摘要")
    func summarySurvivesMainModelSwitch() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        // 大窗口 + 紧急模式：摘要覆盖足够多历史，尾部不被截断，快照可被直接复用。
        let provider = RoutingSummaryProvider(mainContextWindow: 300_000, utilityContextWindow: 100_000)
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let context = LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm)
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        let bigBudget = LLMContextBudget(contextWindowTokens: 300_000, reservedOutputTokens: 2_000, safetyMarginTokens: 1_000)
        let firstRequest = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: provider.providerID,
            model: "main-model",
            budget: bigBudget,
            mode: .emergency
        )
        let first = await context.prepareContext(for: firstRequest)
        #expect(first.didCompact)
        #expect(provider.servedModels == ["utility-model"])

        // 切换对话主模型到同一供应商的另一个模型；摘要作者仍是轻量模型，
        // 快照按作者比较仍然兼容，应直接复用，不再调用摘要接口。
        llm.select(providerID: provider.providerID, model: "main-model-2", reason: .userSelected)
        let secondRequest = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: provider.providerID,
            model: "main-model-2",
            budget: bigBudget,
            mode: .emergency
        )
        let second = await context.prepareContext(for: secondRequest)
        #expect(second.didCompact)
        #expect(provider.completeCalls == 1)
    }

    @Test("轻量模型下线后摘要路由变化并重新生成")
    func summaryRouteChangeInvalidatesSnapshot() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider()
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let context = LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm)
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        _ = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))
        #expect(provider.servedModels == ["utility-model"])

        // 轻量模型从动态池下线：摘要路由回退主模型，旧快照不再兼容，需重新生成。
        provider.availableModels = [LLMModelInfo(id: "main-model", contextWindowSize: 200_000)]
        _ = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))
        #expect(provider.servedModels == ["utility-model", "main-model"])
    }

    @Test("轻量模型摘要失败时回退主模型重试一次")
    func utilityFailureFallsBackToMain() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider()
        provider.failUtility = true
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let ledger = InMemoryAuxiliaryLedger()
        let context = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            auxiliaryUsage: ledger
        )
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        let result = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        #expect(result.didCompact)
        #expect(provider.servedModels == ["utility-model", "main-model"])
        let entries = await ledger.entries(for: conversationID)
        #expect(entries.count == 1)
        #expect(entries.first?.modelName == "main-model")
    }

    // MARK: - #1158 Ledger

    @Test("压缩用量按用途记入账本并带服务模型")
    func compactionUsageRecordedWithServingModel() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider()
        provider.reportedUsage = (input: 1_200, output: 300)
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let ledger = InMemoryAuxiliaryLedger()
        let context = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            auxiliaryUsage: ledger
        )
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        _ = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        let entries = await ledger.entries(for: conversationID)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.purpose == .compaction)
        #expect(entry.modelName == "utility-model")
        #expect(entry.providerID == provider.providerID)
        #expect(entry.isEstimated == false)
        #expect(entry.spentTokens == 1_500)
    }

    @Test("供应商未报用量时记估算值且不为零")
    func missingUsageRecordedAsEstimatedNeverZero() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider()
        provider.reportedUsage = nil
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let ledger = InMemoryAuxiliaryLedger()
        let context = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            auxiliaryUsage: ledger
        )
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        _ = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        let entry = try #require(await ledger.entries(for: conversationID).first)
        #expect(entry.isEstimated)
        let spent = try #require(entry.spentTokens)
        #expect(spent > 0)
        let event = try #require(firstCompactionEvent(messages, conversationID: conversationID))
        #expect(MessageTimelineEvent.compactionSpentIsEstimated(for: event))
        #expect(MessageTimelineEvent.compactionSpentTokens(for: event) == spent)
    }

    @Test("压缩事件净收益 = 节省估算 − 摘要消耗")
    func compactionNetTokensEqualsSavedMinusSpent() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RoutingSummaryProvider()
        provider.reportedUsage = (input: 1_000, output: 200)
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let context = LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm)
        let conversationID = UUID()
        makeLongHistory(messages, conversationID: conversationID)

        _ = await context.prepareContext(for: compactionRequest(conversationID: conversationID, providerID: provider.providerID))

        let event = try #require(firstCompactionEvent(messages, conversationID: conversationID))
        let saved = try #require(MessageTimelineEvent.compactionSavedTokens(for: event))
        let spent = try #require(MessageTimelineEvent.compactionSpentTokens(for: event))
        #expect(spent == 1_200)
        #expect(MessageTimelineEvent.compactionNetTokens(for: event) == saved - spent)
    }

    @Test("账本按用途聚合开销并标注估算/不可用")
    func overheadSummarizesByPurpose() {
        let conversationID = UUID()
        let entries = [
            LLMAuxiliaryUsageEntry(
                conversationID: conversationID, purpose: .compaction, providerID: "p", modelName: "utility-model",
                inputTokenCount: 1_000, outputTokenCount: 200, isEstimated: false
            ),
            LLMAuxiliaryUsageEntry(
                conversationID: conversationID, purpose: .title, providerID: "p", modelName: "utility-model",
                inputTokenCount: 100, outputTokenCount: 20, isEstimated: true
            ),
            LLMAuxiliaryUsageEntry(
                conversationID: conversationID, purpose: .title, providerID: "p", modelName: "utility-model",
                inputTokenCount: nil, outputTokenCount: nil, isEstimated: true
            ),
        ]
        let overheads = LLMAuxiliaryOverhead.summarize(entries)
        #expect(overheads.count == 2)

        let compaction = try? #require(overheads.first { $0.purpose == .compaction })
        #expect(compaction?.callCount == 1)
        #expect(compaction?.spentTokens == 1_200)
        #expect(compaction?.hasEstimatedUsage == false)

        let title = try? #require(overheads.first { $0.purpose == .title })
        #expect(title?.callCount == 2)
        #expect(title?.spentTokens == 120)
        #expect(title?.hasEstimatedUsage == true)
        #expect(title?.hasUnavailableUsage == true)
    }
}