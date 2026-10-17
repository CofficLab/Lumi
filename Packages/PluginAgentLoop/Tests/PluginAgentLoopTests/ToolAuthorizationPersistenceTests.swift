import Foundation
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// 复现：**用户已授权/已拒绝的工具调用，下次打开消息列表又出现授权界面。**
///
/// ## 问题本质
///
/// 「允许 / 拒绝」的唯一落库入口是 `handleAuthorizedToolCompletion` 中那次
/// 带 `authorizationState:` 的 `updateToolCallResult`（`AgentLoopProvider+Tool.swift`）。
/// 它在写库之前有 4 个 guard：runtime 存在、phase 为 `executingTools`、
/// turnID 匹配、pending 含该调用。**任一 guard 失败即静默 return**，
/// 既不写真实结果，也不写 `userApproved` / `userRejected`。
///
/// 消息中的 toolCall 因此永久停留在「等待授权的占位结果 +
/// `pendingAuthorization`」，而这正是 `ToolApprovalRowRenderer.canRender`
/// 判定为「需要显示授权卡片」的两个条件：
///
/// ```
/// authorizationState == .pendingAuthorization
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// 所以用户下次打开消息列表时，授权界面会重新出现——即使上一轮已经
/// 明确点了允许或拒绝。
///
/// - Note: 这些用例**现在应当失败**。它们是缺陷的复现，不是对现状的认可。
///   修复方向是让授权终态的落库不依赖回合状态机的运行时上下文。
@MainActor
@Suite("工具授权终态落库")
struct ToolAuthorizationPersistenceTests {

    /// 构造一条处于「等待用户授权」形态的 assistant 消息。
    ///
    /// 这是 `executeBatch(.requireApprovalForHighRisk)` 命中
    /// `needsUserResponse` 后落库的真实形态：`updateToolCallResult` 写入
    /// `awaitingUserResponse = true` 的占位结果，`authorizationState`
    /// 保持 LLM 响应阶段判定的 `pendingAuthorization`。
    private func makePendingApprovalMessage(
        conversationID: UUID,
        assistantMessageID: UUID,
        turnID: UUID,
        toolCallID: String
    ) -> Message {
        Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [
                MessageToolCall(
                    id: toolCallID,
                    name: "write_file",
                    arguments: #"{"path":"/tmp/a.txt","content":"hi"}"#,
                    result: MessageToolResult(
                        content: #"{"toolCallId":"approval:\#(toolCallID)","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                        awaitingUserResponse: true,
                        interactionState: .waiting
                    ),
                    authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
                )
            ]
        )
    }

    private func makeLoop(
        messages: any MessageManaging
    ) -> AgentLoopManager {
        AgentLoopManager(
            messages: messages,
            llmManager: DefaultLLMManager(),
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
    }

    /// 用户点了「拒绝」，但回合状态机已经走到终态（异步竞争，或回合被取消）。
    ///
    /// 这是最常见的丢失路径：`rejectAuthorized` 通过
    /// `Task { @MainActor }` 派发 `.authorizedCompleted`，而回合可能已在
    /// 事件抵达前结束。此时 phase 命中 `prepareRuntimeForToolResult` 的
    /// `default` 分支并直接返回 false。
    @Test("回合已结束时，用户拒绝的终态仍必须写回消息")
    func rejectionSurvivesTerminalTurnPhase() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call-rejected-after-turn-end"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            makePendingApprovalMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )
        loop.runtimes[conversationID] = TurnRuntime(phase: .completed)

        await loop.handleToolManagerEvent(.authorizedCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: ToolCall(
                id: toolCallID,
                name: "write_file",
                arguments: "{}",
                authorizationState: .userRejected
            ),
            result: ToolCallResult(
                content: "Tool execution was rejected by the user.",
                isError: true
            )
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        // 失败点：授权状态仍是 pendingAuthorization。
        #expect(stored?.authorizationState == ToolCallAuthorizationState.userRejected.rawValue)
        // 占位结果同样没有被替换，消息仍停留在「等待用户响应」形态。
        #expect(stored?.result?.awaitingUserResponse == false)
        #expect(stored?.result?.isError == true)
    }

    /// 事件携带的 turnID 与消息落库的 turnID 不一致。
    ///
    /// 授权卡片是由渲染层重建的，渲染层拿到的 turnID 来自
    /// `ToolApprovalBridge.resolve` → `agentLoop.currentTurnID`；消息里的
    /// turnID 则来自 LLM 响应落库。两者一旦不同步（重启、恢复路径、
    /// 多回合交错），事件就会被 turnID 判据丢弃。
    @Test("turnID 不一致时，用户授权的终态仍必须写回消息")
    func approvalSurvivesMismatchedTurnID() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let messageTurnID = UUID()
        let eventTurnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call-approved-turn-mismatch"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            makePendingApprovalMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: messageTurnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )
        loop.runtimes[conversationID] = TurnRuntime(
            phase: .executingTools(
                turnID: messageTurnID,
                assistantMessageID: assistantMessageID,
                pendingToolCalls: [MessageToolCall(id: toolCallID, name: "write_file", arguments: "{}")]
            )
        )

        await loop.handleToolManagerEvent(.authorizedCompleted(
            conversationID: conversationID,
            turnID: eventTurnID,
            toolCall: ToolCall(
                id: toolCallID,
                name: "write_file",
                arguments: "{}",
                authorizationState: .userApproved
            ),
            result: ToolCallResult(content: "file written")
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        #expect(stored?.authorizationState == ToolCallAuthorizationState.userApproved.rawValue)
        #expect(stored?.result?.content == "file written")
    }

    /// 「用户已决定」的语义不应依赖回合状态机是否还在内存里。
    ///
    /// 这一条从「无 runtime」角度验证同一语义：`runtimes` 为空时
    /// `prepareRuntimeForToolResult` 会走消息恢复分支重建运行时。
    /// 该分支能重建运行时，但其 pending 只收集
    /// `result == nil || awaitingUserResponse` 的调用，恢复是否恰好接住
    /// 这次终态取决于 pending 判定——因此这里只断言
    /// 「终态不得被静默丢弃」这一层不变量。
    ///
    /// - Note: 前两条已分别从 phase 与 turnID 两个角度证明该不变量被违反，
    ///   修复时以它们为准。
    @Test("授权终态不会因为状态机缺失而停留在等待授权形态")
    func resolvedAuthorizationIsNeverLeftPending() async {
        for outcome in [ToolCallAuthorizationState.userApproved, .userRejected] {
            let messages = DefaultMessageManager()
            let conversationID = UUID()
            let assistantMessageID = UUID()
            let turnID = UUID()
            let toolCallID = "call-\(outcome.rawValue)"
            let loop = makeLoop(messages: messages)

            messages.insertMessage(
                makePendingApprovalMessage(
                    conversationID: conversationID,
                    assistantMessageID: assistantMessageID,
                    turnID: turnID,
                    toolCallID: toolCallID
                ),
                to: conversationID
            )

            await loop.handleToolManagerEvent(.authorizedCompleted(
                conversationID: conversationID,
                turnID: turnID,
                toolCall: ToolCall(
                    id: toolCallID,
                    name: "write_file",
                    arguments: "{}",
                    authorizationState: outcome
                ),
                result: ToolCallResult(
                    content: outcome == .userApproved ? "done" : "Tool execution was rejected by the user.",
                    isError: outcome == .userRejected
                )
            ))

            let stored = messages.message(id: assistantMessageID, in: conversationID)?
                .toolCalls?.first(where: { $0.id == toolCallID })
            #expect(
                stored?.authorizationState != ToolCallAuthorizationState.pendingAuthorization.rawValue,
                "授权终态 \(outcome.rawValue) 未写回，消息仍会再次弹出授权界面"
            )
            #expect(
                stored?.result?.awaitingUserResponse == false,
                "授权终态 \(outcome.rawValue) 未替换占位结果，消息仍会再次弹出授权界面"
            )
        }
    }
}
