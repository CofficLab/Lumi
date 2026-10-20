import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListStandard

/// 复现：**用户已处理过工具授权，切到其他对话再切回来，授权界面又出现。**
///
/// 与 V3 侧同构（见 `ListV3AuthorizationAfterSwitchTests`）：
/// V2（标准模式）与 V3（详细模式）各有自己的行重建指纹，
/// 两边都得保证「切回来之后行里带的是授权终态」。
///
/// ## 这一层锁住什么
///
/// 授权卡片是否出现取决于行里的工具调用是不是仍处于「等待授权」形态：
///
/// ```
/// authorizationState == .pendingAuthorization
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// 因此这里锁的是：**切走再切回后，行里必须带授权终态**。
/// 只要行里还是 `pendingAuthorization`，渲染层就会再弹一次授权卡片。
///
/// 渲染层自身的判据由 `ToolApprovalVisibilityAfterResolutionTests` 与
/// `ToolApprovalAfterConversationSwitchTests`（PluginMessageRenderer）覆盖；
/// 「授权终态有没有落库」由 `ToolAuthorizationPersistenceTests`
/// （PluginAgentLoop）覆盖。本文件覆盖中间那一段：**列表把终态带回来**。
@MainActor
@Suite("授权处理后切换对话，列表行带授权终态")
struct ListV2AuthorizationAfterSwitchTests {

    // MARK: - 夹具

    /// 一条带工具调用的助手消息。
    private func assistantMessage(
        id: UUID = UUID(),
        conversationID: UUID,
        toolCall: MessageToolCall
    ) -> Message {
        makeMessage(
            id: id,
            conversationID: conversationID,
            role: .assistant,
            // 非空正文：避免被 `isToolExecutionOnly` 合并成 tool-step-group，
            // 让断言直接落在这一条消息上。
            content: "我要写入一个文件",
            toolCalls: [toolCall]
        )
    }

    /// 等待用户授权时的工具调用形态。
    ///
    /// 对应 `MessageModel.from` 的轻量化插入（`result` 置 nil）与
    /// `ToolExecutionManager` 命中高风险工具后的占位结果。
    private func pendingToolCall(id: String, withResult: Bool) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: "edit_file",
            arguments: #"{"path":"/tmp/a.txt"}"#,
            result: withResult
                ? MessageToolResult(
                    content: #"{"toolCallId":"approval:\#(id)","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                    awaitingUserResponse: true,
                    interactionState: .waiting
                )
                : nil,
            displayDescription: "写入 /tmp/a.txt",
            authorizationState: "pendingAuthorization"
        )
    }

    /// 用户已处理后消息里的工具调用形态。
    private func resolvedToolCall(id: String, outcome: String) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: "edit_file",
            arguments: #"{"path":"/tmp/a.txt"}"#,
            result: MessageToolResult(
                content: outcome == "userApproved"
                    ? "file written"
                    : "Tool execution was rejected by the user.",
                isError: outcome == "userRejected"
            ),
            displayDescription: "写入 /tmp/a.txt",
            authorizationState: outcome
        )
    }

    /// 行里那条助手消息携带的工具调用。
    private func toolCall(in rows: [Message], messageID: UUID) -> MessageToolCall? {
        rows.first(where: { $0.id == messageID })?.toolCalls?.first
    }

    // MARK: - 用例

    /// 用户点了「允许」，切走再切回后行里必须带 `userApproved`。
    ///
    /// 切走再切回是用户最容易复现的路径：切换会话会重建列表、
    /// 重新从数据源取消息，若取回的是授权前的快照，
    /// 授权卡片就会重新弹出来。
    @Test("已允许的工具调用在切走再切回后仍是授权终态")
    func approvedToolCallKeepsTerminalStateAfterSwitchingBack() async {
        let conversationA = UUID()
        let conversationB = UUID()
        let messageID = UUID()
        let toolCallID = "call-approved-list"

        let messages = StubMessageListMessageCapability(
            page: [
                assistantMessage(
                    id: messageID,
                    conversationID: conversationA,
                    toolCall: pendingToolCall(id: toolCallID, withResult: true)
                )
            ]
        )
        let harness = ViewModelHarness(selected: conversationA, messages: messages)
        await harness.viewModel.activate(conversationID: conversationA)

        // 授权前：行里确实是「等待授权」形态，授权卡片应当出现。
        #expect(
            toolCall(in: harness.viewModel.historyRows, messageID: messageID)?.authorizationState
                == "pendingAuthorization"
        )

        // 用户点了「允许」：消息被回写成授权终态并落库。
        messages.page = [
            assistantMessage(
                id: messageID,
                conversationID: conversationA,
                toolCall: resolvedToolCall(id: toolCallID, outcome: "userApproved")
            )
        ]

        // 切到另一个对话。
        harness.conversations.selectedConversationID = conversationB
        messages.page = []
        await harness.viewModel.activate(conversationID: conversationB)
        #expect(harness.viewModel.historyRows.isEmpty)

        // 切回原对话。
        harness.conversations.selectedConversationID = conversationA
        messages.page = [
            assistantMessage(
                id: messageID,
                conversationID: conversationA,
                toolCall: resolvedToolCall(id: toolCallID, outcome: "userApproved")
            )
        ]
        await harness.viewModel.activate(conversationID: conversationA)

        let restored = toolCall(in: harness.viewModel.historyRows, messageID: messageID)
        #expect(
            restored?.authorizationState == "userApproved",
            "切回对话后行里仍是等待授权的旧快照，授权卡片会重新出现"
        )
        #expect(
            restored?.result?.awaitingUserResponse == false,
            "切回对话后行里仍带着等待授权的占位结果，授权卡片会重新出现"
        )
    }

    /// 用户点了「拒绝」，切走再切回后同样必须带 `userRejected`。
    @Test("已拒绝的工具调用在切走再切回后仍是授权终态")
    func rejectedToolCallKeepsTerminalStateAfterSwitchingBack() async {
        let conversationA = UUID()
        let conversationB = UUID()
        let messageID = UUID()
        let toolCallID = "call-rejected-list"

        let messages = StubMessageListMessageCapability(
            page: [
                assistantMessage(
                    id: messageID,
                    conversationID: conversationA,
                    toolCall: pendingToolCall(id: toolCallID, withResult: true)
                )
            ]
        )
        let harness = ViewModelHarness(selected: conversationA, messages: messages)
        await harness.viewModel.activate(conversationID: conversationA)

        messages.page = [
            assistantMessage(
                id: messageID,
                conversationID: conversationA,
                toolCall: resolvedToolCall(id: toolCallID, outcome: "userRejected")
            )
        ]

        harness.conversations.selectedConversationID = conversationB
        messages.page = []
        await harness.viewModel.activate(conversationID: conversationB)

        harness.conversations.selectedConversationID = conversationA
        messages.page = [
            assistantMessage(
                id: messageID,
                conversationID: conversationA,
                toolCall: resolvedToolCall(id: toolCallID, outcome: "userRejected")
            )
        ]
        await harness.viewModel.activate(conversationID: conversationA)

        let restored = toolCall(in: harness.viewModel.historyRows, messageID: messageID)
        #expect(
            restored?.authorizationState == "userRejected",
            "切回对话后行里仍是等待授权的旧快照，授权卡片会重新出现"
        )
    }

    /// 授权状态变化本身就会触发历史行重建。
    ///
    /// 授权终态是通过「消息更新」事件推进的：消息被回写 → 列表收到
    /// `.updated` → 尾部刷新 → 重建历史行。重建是否发生取决于
    /// `HistoryBuildSignature` 指纹——授权状态必须在内，
    /// 否则「结果没变、只有授权状态变了」会被指纹判定为「没变」而跳过重建。
    @Test("授权状态变化本身就会触发历史行重建")
    func authorizationStateChangeAloneTriggersRebuild() async {
        let conversationID = UUID()
        let messageID = UUID()
        let toolCallID = "call-state-only-change"

        // 授权前：结果为 nil（轻量化插入后的形态），授权状态待授权。
        let messages = StubMessageListMessageCapability(
            page: [
                assistantMessage(
                    id: messageID,
                    conversationID: conversationID,
                    toolCall: pendingToolCall(id: toolCallID, withResult: false)
                )
            ]
        )
        let harness = ViewModelHarness(selected: conversationID, messages: messages)
        await harness.viewModel.activate(conversationID: conversationID)
        #expect(
            toolCall(in: harness.viewModel.historyRows, messageID: messageID)?.authorizationState
                == "pendingAuthorization"
        )

        // 用户已允许，但结果仍是 nil —— 只有授权状态变了。
        messages.page = [
            assistantMessage(
                id: messageID,
                conversationID: conversationID,
                toolCall: MessageToolCall(
                    id: toolCallID,
                    name: "edit_file",
                    arguments: #"{"path":"/tmp/a.txt"}"#,
                    result: nil,
                    displayDescription: "写入 /tmp/a.txt",
                    authorizationState: "userApproved"
                )
            )
        ]
        harness.viewModel.handleMessageChange(.updated(conversationID: conversationID))
        // 尾部刷新是异步任务，等它落地。
        _ = await harness.viewModel.refreshTail()

        let updated = toolCall(in: harness.viewModel.historyRows, messageID: messageID)
        #expect(
            updated?.authorizationState == "userApproved",
            "只有授权状态变化时历史行没有重建，行里仍是等待授权的旧快照"
        )
    }
}
