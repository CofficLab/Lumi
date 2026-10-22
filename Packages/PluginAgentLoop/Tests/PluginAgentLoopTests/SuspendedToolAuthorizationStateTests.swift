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

/// 复现：**A3（完全授权）对话中，工具自身请求授权时授权卡片不出现，回合永久挂起。**
///
/// ## 现象
///
/// 用户在 A3 对话里让 Agent 操作某个未授权应用（如 App Store），Agent 调用
/// `accessibility_observe`，工具按设计返回 `awaitingUserResponse = true`
/// 的挂起结果。AgentLoop 随即挂起回合、输入区显示「等待你的输入…」。
/// 但界面上**没有出现任何可点击的授权卡片**——只剩一条工具行和一坨
/// JSON 原始输出。用户既看不到卡片也无法推进，对话永久停住。
///
/// ## 根因
///
/// 授权卡片由渲染层判定，条件是：
///
/// ```
/// authorizationState == .pendingAuthorization
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// （见 `ToolApprovalRowRenderer.canRender` 与
/// `ComputerUseAuthorizationRowRenderer.canRender`）
///
/// 但 `authorizationState` 在 **LLM 响应落库阶段**就已写死：A3 走
/// `ToolManager.authorizationDecision` 的 `.autonomous` 分支，一律返回
/// `.autoApproved`（`ToolManager.swift`）。之后工具在**执行阶段**返回挂起
/// 结果时，`AgentLoopProvider+Tool.swift` 调用 `updateToolCallResult` 并**没有
/// 传 `authorizationState` 参数**，于是先前写入的 `autoApproved` 被原样保留。
///
/// 结果是「回合已挂起」与「授权状态仍是自动同意」互相矛盾：回合在等一个
/// 永远不会到来的回答，渲染层又认为没有待处理的授权。
///
/// ## 修复方向
///
/// 工具挂起时，消息里的 `authorizationState` 必须回落为 `pendingAuthorization`
/// ——挂起本身就是「现在需要用户决定」的事实，与工具的风险等级无关。
/// 落库入口是 `MessageManager.updateToolCallResult(..., authorizationState:)`，
/// 该参数已经存在，只是挂起路径没有使用它。
///
/// - Note: 这些用例**现在应当失败**。它们是缺陷的复现，不是对现状的认可。
@MainActor
@Suite("工具挂起时的授权状态回落")
struct SuspendedToolAuthorizationStateTests {

    /// A3 对话中，工具因应用未授权而挂起回合时，
    /// 消息里的授权状态必须变回 `pendingAuthorization`。
    ///
    /// 这是复现主路径：`.executed` 分支下工具返回
    /// `awaitingUserResponse = true` 的挂起结果。
    @Test("工具挂起时授权状态回落为 pendingAuthorization")
    func suspensionResetsAuthorizationStateToPending() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_suspend_1"
        let loop = makeLoop(messages: messages)

        // 消息形态与 A3 下的真实落库一致：LLM 响应阶段已把授权状态写成
        // autoApproved（.autonomous 分支），此时工具尚未执行。
        messages.insertMessage(
            autoApprovedToolCallMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "accessibility_observe",
                arguments: #"{"application":"App Store"}"#,
                authorizationState: .autoApproved
            )],
            results: [.executed(ToolCallResult(
                content: authorizationPayload,
                isError: false,
                awaitingUserResponse: true,
                interactionState: .waiting
            ))]
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        // 失败点：状态仍是 autoApproved，渲染层因此不画授权卡片。
        #expect(
            stored?.authorizationState == ToolCallAuthorizationState.pendingAuthorization.rawValue,
            "工具挂起后授权状态必须回落为 pendingAuthorization，实际：\(stored?.authorizationState ?? "nil")"
        )
        // 挂起结果本身必须落库，否则界面看不到等待状态。
        #expect(stored?.result?.awaitingUserResponse == true)
        #expect(stored?.result?.interactionState == .waiting)
    }

    /// 同一条不变量在 `.needsUserResponse` 分支上同样成立。
    ///
    /// 该分支由 `executeBatch` 在 `requireApprovalForHighRisk` 策略下产出，
    /// 走的是另一处 `updateToolCallResult` 调用点。两条路径必须一致，
    /// 否则会出现「一个分支能画卡片、另一个不能」的不一致行为。
    @Test("needsUserResponse 分支同样回落为 pendingAuthorization")
    func needsUserResponseBranchResetsAuthorizationState() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_suspend_2"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            autoApprovedToolCallMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "accessibility_observe",
                arguments: #"{"application":"App Store"}"#,
                authorizationState: .autoApproved
            )],
            results: [.needsUserResponse(payload: authorizationPayload)]
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        #expect(
            stored?.authorizationState == ToolCallAuthorizationState.pendingAuthorization.rawValue,
            "needsUserResponse 分支必须把授权状态回落为 pendingAuthorization，实际：\(stored?.authorizationState ?? "nil")"
        )
        #expect(stored?.result?.awaitingUserResponse == true)
    }

    /// 挂起后回合必须真的进入「等待用户」状态。
    ///
    /// 这条不是缺陷本身，而是防止修复时把挂起语义整体破坏掉：
    /// 回落授权状态不得让回合继续跑或直接结束。
    @Test("挂起后回合停在等待用户输入")
    func suspensionStillPutsTurnIntoAwaitingUser() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_suspend_3"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            autoApprovedToolCallMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "accessibility_observe",
                arguments: #"{"application":"App Store"}"#,
                authorizationState: .autoApproved
            )],
            results: [.executed(ToolCallResult(
                content: authorizationPayload,
                isError: false,
                awaitingUserResponse: true,
                interactionState: .waiting
            ))]
        ))

        #expect(loop.state(for: conversationID) == .suspended)
        #expect(loop.suspension(for: conversationID)?.toolCallID == toolCallID)
    }

    /// 正常完成（不挂起）的工具调用不得被改成 `pendingAuthorization`。
    ///
    /// 回落只应发生在「确实在等用户回答」时；否则每个已完成的工具调用都会
    /// 残留一个「待授权」状态，界面会反复弹出授权卡片。
    @Test("正常完成的工具调用不回落授权状态")
    func completedToolCallKeepsItsAuthorizationState() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_suspend_4"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            autoApprovedToolCallMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "read_file",
                arguments: "{}",
                authorizationState: .autoApproved
            )],
            results: [.executed(ToolCallResult(content: "file contents"))]
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        #expect(
            stored?.authorizationState == ToolCallAuthorizationState.autoApproved.rawValue,
            "未挂起的工具调用不得被改成待授权状态，实际：\(stored?.authorizationState ?? "nil")"
        )
        #expect(stored?.result?.awaitingUserResponse == false)
    }

    // MARK: - 夹具

    /// Computer Use 应用级授权的挂起载荷，形状与生产一致。
    private let authorizationPayload = #"{"kind":"computer_use_authorization","request":{"applicationName":"App Store","bundleIdentifier":"com.apple.AppStore","operation":"accessibility_observe"},"options":["allowOnce","alwaysAllow","deny"]}"#

    /// 构造一条 A3 对话下 LLM 响应刚落库时的 assistant 消息。
    ///
    /// `authorizationState` 固定为 `autoApproved`：这是 A3 完全授权下
    /// `ToolManager.authorizationDecision` 的真实判定结果。
    private func autoApprovedToolCallMessage(
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
                    name: "accessibility_observe",
                    arguments: #"{"application":"App Store"}"#,
                    displayDescription: "读取应用控件",
                    authorizationState: ToolCallAuthorizationState.autoApproved.rawValue
                )
            ]
        )
    }

    private func makeLoop(messages: any MessageManaging) -> AgentLoopManager {
        AgentLoopManager(
            messages: messages,
            llmManager: DefaultLLMManager(),
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
    }
}
