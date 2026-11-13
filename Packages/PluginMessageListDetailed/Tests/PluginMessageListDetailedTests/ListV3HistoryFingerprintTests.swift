import Foundation
import ProviderConversationState
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

/// V3（detailed）历史行指纹必须覆盖**所有影响渲染的输入**（#147）。
///
/// `rebuildHistoryRows` 用 `HistoryBuildSignatureV3` 做去重：签名不变就
/// `guard ... else { return }` 跳过重建。曾经的 `MessageFingerprintV3` 只纳入
/// id / content.hashValue / role / isToolExecutionOnly / 工具结果**长度** /
/// awaitingUserResponse / 授权状态，漏掉了：
///
/// - `reasoningContent`（V3 详细模式**会显示**思考内容）；
/// - 工具结果的**完整文本**（只比长度，等长替换漏刷新）；
/// - 工具结果的 `isError`；
/// - 工具结果的 `interactionState`。
///
/// 于是「数据层已更新、但签名没变」的真实回写被吞掉，UI 继续显示旧思考 /
/// 旧工具输出 / 旧状态。这组用例通过可观测的 `historyRows` 重建来锁定不变量，
/// 不依赖任何哈希碰撞即可复现。
@MainActor
@Suite("V3 历史指纹覆盖渲染输入")
struct ListV3HistoryFingerprintTests {

    // MARK: - 装配

    @MainActor
    private func makeHarness(
        selected: UUID?,
        messages: any MessageListMessageCapability
    ) -> ListV3ViewModel {
        let conversations = StubConversationCapability(selectedConversationID: selected)
        let conversationState = StubConversationStateCapability(
            snapshot: ConversationStateSnapshot(
                conversationID: selected ?? UUID(),
                activity: nil
            )
        )
        return ListV3ViewModel(
            services: MessageListServices(
                conversations: conversations,
                conversationState: conversationState,
                developerModeState: DeveloperModeStateViewModel(),
                messages: messages,
                rendering: nil,
                streaming: StubStreamingCapability(),
                toolManager: StubToolManagerCapability(),
                agentTurn: StubAgentLoopCapability(),
                promptSuggestions: nil,
                promptSuggestionExecutor: nil,
                project: nil,
                toolbar: nil,
                chat: nil
            ),
            pagination: MessageListPaginationService(pageSize: 40, maxRetainedCount: 300),
            streamingDisplayEnabled: false
        )
    }

    /// 构造一条「只含工具调用、正文为空」的助手消息（合成行路径）。
    private func toolMessage(
        id: UUID,
        conversationID: UUID,
        turnID: UUID,
        result: MessageToolResult
    ) -> Message {
        Message(
            id: id,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [
                MessageToolCall(
                    id: "call-1",
                    name: "run_command",
                    arguments: "{}",
                    result: result
                )
            ]
        )
    }

    // MARK: - 同 id 同正文，新增思考内容

    @Test("同 id 同正文的消息新增 reasoningContent 后历史行必须重建")
    func sameIDSameBodyNewReasoningRebuildsRows() async {
        let conversationID = UUID()
        let messageID = UUID()
        let original = Message(
            id: messageID,
            conversationID: conversationID,
            role: .assistant,
            content: "Body",
            reasoningContent: nil
        )
        let manager = StubMessageListMessageCapability(page: [original])
        let viewModel = makeHarness(selected: conversationID, messages: manager)
        await viewModel.activateCurrentConversation()
        #expect(viewModel.historyRows.first?.reasoningContent == nil)

        // 同 id、同正文，仅新增思考内容。
        manager.setPage([
            Message(
                id: messageID,
                conversationID: conversationID,
                role: .assistant,
                content: "Body",
                reasoningContent: "思考过程 R"
            )
        ])
        _ = await viewModel.refreshTail()

        #expect(
            viewModel.historyRows.first?.reasoningContent == "思考过程 R",
            "新增 reasoningContent 后历史行仍是旧快照「\(viewModel.historyRows.first?.reasoningContent ?? "nil")」"
        )
    }

    // MARK: - 等长工具结果文本替换

    @Test("工具结果等长文本替换后历史行必须更新")
    func equalLengthToolResultTextRebuildsRows() async {
        let conversationID = UUID()
        let turnID = UUID()
        let messageID = UUID()
        let original = toolMessage(
            id: messageID,
            conversationID: conversationID,
            turnID: turnID,
            result: MessageToolResult(content: "old!")
        )
        let manager = StubMessageListMessageCapability(page: [original])
        let viewModel = makeHarness(selected: conversationID, messages: manager)
        await viewModel.activateCurrentConversation()
        #expect(viewModel.historyRows.first?.toolCalls?.first?.result?.content == "old!")

        // 等长替换："old!" → "new!"（长度都是 4）。
        manager.setPage([
            toolMessage(
                id: messageID,
                conversationID: conversationID,
                turnID: turnID,
                result: MessageToolResult(content: "new!")
            )
        ])
        _ = await viewModel.refreshTail()

        #expect(
            viewModel.historyRows.first?.toolCalls?.first?.result?.content == "new!",
            "等长工具结果替换后仍是旧快照「\(viewModel.historyRows.first?.toolCalls?.first?.result?.content ?? "nil")」"
        )
    }

    // MARK: - 工具结果错误标志变化

    @Test("工具结果 isError 翻转后历史行必须更新")
    func toolResultErrorFlagChangeRebuildsRows() async {
        let conversationID = UUID()
        let turnID = UUID()
        let messageID = UUID()
        let original = toolMessage(
            id: messageID,
            conversationID: conversationID,
            turnID: turnID,
            result: MessageToolResult(content: "same", isError: false)
        )
        let manager = StubMessageListMessageCapability(page: [original])
        let viewModel = makeHarness(selected: conversationID, messages: manager)
        await viewModel.activateCurrentConversation()
        #expect(viewModel.historyRows.first?.toolCalls?.first?.result?.isError == false)

        // 仅 isError 翻转，文本/长度/awaiting 全不变。
        manager.setPage([
            toolMessage(
                id: messageID,
                conversationID: conversationID,
                turnID: turnID,
                result: MessageToolResult(content: "same", isError: true)
            )
        ])
        _ = await viewModel.refreshTail()

        #expect(
            viewModel.historyRows.first?.toolCalls?.first?.result?.isError == true,
            "isError 翻转后历史行仍显示旧错误标志"
        )
    }

    // MARK: - 工具结果交互状态变化

    @Test("工具结果 interactionState 变化后历史行必须更新")
    func toolResultInteractionStateChangeRebuildsRows() async {
        let conversationID = UUID()
        let turnID = UUID()
        let messageID = UUID()
        let original = toolMessage(
            id: messageID,
            conversationID: conversationID,
            turnID: turnID,
            result: MessageToolResult(content: "same", interactionState: nil)
        )
        let manager = StubMessageListMessageCapability(page: [original])
        let viewModel = makeHarness(selected: conversationID, messages: manager)
        await viewModel.activateCurrentConversation()
        #expect(viewModel.historyRows.first?.toolCalls?.first?.result?.interactionState == nil)

        // 仅 interactionState 变化，文本/长度/awaiting/isError 全不变。
        manager.setPage([
            toolMessage(
                id: messageID,
                conversationID: conversationID,
                turnID: turnID,
                result: MessageToolResult(content: "same", interactionState: .answered("yes"))
            )
        ])
        _ = await viewModel.refreshTail()

        #expect(
            viewModel.historyRows.first?.toolCalls?.first?.result?.interactionState == .answered("yes"),
            "interactionState 变化后历史行仍显示旧交互状态"
        )
    }
}
