import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// ContextToolbar 的数据刷新编排（#1257）。
///
/// 按钮常显数据（用量、压缩事件）无论弹窗开关都要刷新；仅弹窗展示的
/// 数据（趋势曲线、幕后调用用量）闭窗时必须跳过，打开弹窗时补拉。
/// 闭窗时的每轮去抖刷新因此少做两次全量快照读取与整史构建。
@MainActor
@Suite("上下文工具栏数据刷新编排")
struct ContextToolbarDataTests {

    private final class RefreshProvider: SuperLLMProvider {
        let providerInfo: LLMProviderInfo
        var availableModels: [LLMModelInfo]
        init() {
            let models = [LLMModelInfo(id: "main-model", contextWindowSize: 200_000)]
            providerInfo = LLMProviderInfo(
                id: "refresh-provider",
                displayName: "refresh-provider",
                defaultModel: "main-model",
                models: models
            )
            availableModels = models
        }
        var providerID: String { providerInfo.id }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "ok", model: request.model ?? "")
        }
    }

    private func makeData() throws -> (ContextToolbarData, UUID) {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = RefreshProvider()
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        let contextProvider = LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm)
        let id = UUID()
        messages.insertMessage(Message(conversationID: id, role: .user, content: "第一条问题"), to: id)
        messages.insertMessage(
            Message(conversationID: id, role: .assistant, content: "回答", inputTokenCount: 500),
            to: id
        )
        // 一条真实压缩事件：按钮上的事件徽标来源。
        messages.insertMessage(
            Message(
                conversationID: id, role: .assistant, content: "上下文已压缩",
                metadata: [
                    MessageTimelineEvent.actualContextCompactionKey: MessageTimelineEvent.actualContextCompactionValue,
                ],
                renderKind: MessageTimelineEvent.contextCompactionRenderKind
            ),
            to: id
        )
        return (ContextToolbarData(provider: contextProvider, messages: messages), id)
    }

    @Test("闭窗刷新只取按钮数据：用量与压缩事件，跳过曲线与幕后账本")
    func closedRefreshLoadsOnlyVisibleData() async throws {
        let (data, id) = try makeData()
        data.setSelectedConversationID(id)

        await data.refresh(isPopoverPresented: false, for: id)

        #expect(data.usage != nil, "用量是按钮常显数据，闭窗也要刷新")
        #expect(!data.events.isEmpty, "压缩事件徽标是按钮常显数据，闭窗也要刷新")
        #expect(data.history == .empty, "闭窗时不得读取全量快照构建趋势曲线")
        #expect(data.auxiliaryEntries.isEmpty, "闭窗时不得读取幕后调用账本")
    }

    @Test("开窗刷新取全部数据")
    func openRefreshLoadsAllData() async throws {
        let (data, id) = try makeData()
        data.setSelectedConversationID(id)

        await data.refresh(isPopoverPresented: true, for: id)

        #expect(data.usage != nil)
        #expect(!data.events.isEmpty)
        #expect(data.history != .empty, "开窗后趋势曲线被构建")
    }

    @Test("打开弹窗补拉仅弹窗展示的数据")
    func popoverOpenRefetchesPopoverOnlyData() async throws {
        let (data, id) = try makeData()
        data.setSelectedConversationID(id)

        await data.refresh(isPopoverPresented: false, for: id)
        #expect(data.history == .empty)

        await data.refreshPopoverOnly(for: id)
        #expect(data.history != .empty, "打开弹窗后趋势曲线被补拉构建")
    }
}
