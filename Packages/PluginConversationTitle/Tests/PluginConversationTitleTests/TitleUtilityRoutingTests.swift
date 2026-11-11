import Foundation
import KernelCore
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginConversationTitle

/// 记录服务模型并可注入用量的标题供应商。
@MainActor
private final class TitleRoutingProvider: SuperLLMProvider {
    let providerInfo: LLMProviderInfo
    private(set) var servedModels: [String] = []
    var reportedUsage: (input: Int, output: Int)?
    var titleText = "自动标题"

    init(recommendedUtilityModel: String? = "utility-model") {
        providerInfo = LLMProviderInfo(
            id: "title-provider",
            displayName: "title-provider",
            defaultModel: "main-model",
            models: [
                LLMModelInfo(id: "main-model"),
                LLMModelInfo(id: "utility-model"),
            ],
            recommendedUtilityModel: recommendedUtilityModel
        )
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        servedModels.append(request.model ?? "")
        if let reportedUsage {
            return LLMResponse(
                content: titleText,
                model: request.model,
                inputTokenCount: reportedUsage.input,
                outputTokenCount: reportedUsage.output
            )
        }
        return LLMResponse(content: titleText, model: request.model)
    }
}

/// 纯内存幕后账本替身。
@MainActor
private final class TitleLedgerSpy: LLMAuxiliaryUsageProviding {
    private(set) var recorded: [LLMAuxiliaryUsageEntry] = []

    func record(_ entry: LLMAuxiliaryUsageEntry) async {
        recorded.append(entry)
    }

    func entries(for conversationID: UUID) async -> [LLMAuxiliaryUsageEntry] {
        recorded.filter { $0.conversationID == conversationID }
    }
}

/// #1157 标题轻量模型路由 + #1158 标题用量记账。
@Suite("标题轻量模型与用量")
@MainActor
struct TitleUtilityRoutingTests {

    private func makeLLM(provider: TitleRoutingProvider) throws -> DefaultLLMManager {
        let llm = DefaultLLMManager()
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        return llm
    }

    /// 标题生成链路含多次 async 跳转，轮询等待标题落库后再断言。
    private func waitForTitle(
        _ conversations: TitleTestDoubles.StubConversationManager,
        id: UUID
    ) async {
        for _ in 0..<200 {
            if conversations.title(of: id) != nil { return }
            await Task.yield()
        }
    }

    @Test("声明轻量模型时标题路由到轻量模型")
    func titleRoutesToUtilityModel() async throws {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let provider = TitleRoutingProvider()
        let llm = try makeLLM(provider: provider)
        let service = TitleService(
            kernel: KernelCoreContainer(),
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
        defer { service.stop() }

        messages.emitInserted(Message(conversationID: conversationID, role: .user, content: "帮我写个排序算法"))
        await waitForTitle(conversations, id: conversationID)

        #expect(provider.servedModels == ["utility-model"])
        #expect(conversations.title(of: conversationID) == "自动标题")
    }

    @Test("未声明轻量模型时标题沿用主模型")
    func titleWithoutDeclarationUsesMainModel() async throws {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let provider = TitleRoutingProvider(recommendedUtilityModel: nil)
        let llm = try makeLLM(provider: provider)
        let service = TitleService(
            kernel: KernelCoreContainer(),
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
        defer { service.stop() }

        messages.emitInserted(Message(conversationID: conversationID, role: .user, content: "首个问题"))
        await waitForTitle(conversations, id: conversationID)

        #expect(provider.servedModels == ["main-model"])
        #expect(conversations.title(of: conversationID) == "自动标题")
    }

    @Test("标题用量按用途记入账本并带服务模型")
    func titleUsageRecordedToLedger() async throws {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let provider = TitleRoutingProvider()
        provider.reportedUsage = (input: 50, output: 10)
        let llm = try makeLLM(provider: provider)
        let ledger = TitleLedgerSpy()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LLMAuxiliaryUsageProviding).self, ledger)
        let service = TitleService(
            kernel: kernel,
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
        defer { service.stop() }

        messages.emitInserted(Message(conversationID: conversationID, role: .user, content: "首个问题"))
        await waitForTitle(conversations, id: conversationID)

        let entries = await ledger.entries(for: conversationID)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.purpose == .title)
        #expect(entry.modelName == "utility-model")
        #expect(entry.providerID == provider.providerID)
        #expect(entry.isEstimated == false)
        #expect(entry.spentTokens == 60)
    }

    @Test("供应商未报用量时标题用量记估算值且不为零")
    func titleUsageEstimatedWhenUnreported() async throws {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let provider = TitleRoutingProvider()
        provider.reportedUsage = nil
        let llm = try makeLLM(provider: provider)
        let ledger = TitleLedgerSpy()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LLMAuxiliaryUsageProviding).self, ledger)
        let service = TitleService(
            kernel: kernel,
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
        defer { service.stop() }

        messages.emitInserted(Message(conversationID: conversationID, role: .user, content: "首个问题"))
        await waitForTitle(conversations, id: conversationID)

        let entry = try #require(await ledger.entries(for: conversationID).first)
        #expect(entry.purpose == .title)
        #expect(entry.isEstimated)
        let spent = try #require(entry.spentTokens)
        #expect(spent > 0)
    }
}