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

/// 复现：**`ask_user` 的挂起被当成「待授权」，与「等回答」混为一谈。**
///
/// ## 现象
///
/// 用户反馈界面偶尔出现「无法解析工具审批请求」，但流程一切正常。
/// 渲染层的根因在 `ToolApprovalRowRenderer.canRender`（它只看
/// `pendingAuthorization` + `awaitingUserResponse`），但**成因**在 AgentLoop：
/// 提交 `9bc46bfea` 之后，`AgentLoopProvider+Tool.swift` 在持久化任何挂起结果时
/// 都把授权状态回落为 `pendingAuthorization`，**不区分挂起原因**。
///
/// ## 两种挂起不是一回事
///
/// | 挂起类型 | 载荷 | 谁来决定 | 需要的授权状态 |
/// |---|---|---|---|
/// | 工具授权（`kind == "permission"`） | 授权载荷 | 用户点「允许/拒绝」 | `pendingAuthorization` |
/// | 工具交互（`ask_user`） | 提问载荷 | 用户回答问题 | `autoApproved`（不需要授权） |
///
/// `ask_user` 的风险等级恒为 `.safe`（`AskUserTool.permissionRiskLevel`），
/// 它从来不需要「授权」，只需要「回答」。把它标成 `pendingAuthorization` 就等于
/// 对渲染层说「这里有一次待处理的工具授权」——而授权卡片构造不出请求，
/// 于是渲染出「无法解析工具审批请求」。
///
/// ## 这一层锁住什么
///
/// 本文件锁住**AgentLoop 侧的成因**：挂起回落必须按挂起类型区分，不能一刀切。
/// 渲染层的误接管判据由 `ToolApprovalMisclaimTests`
/// （PluginMessageRenderer）覆盖。
@MainActor
@Suite("挂起回落必须区分授权与交互")
struct SuspendedInteractionStateTests {

    /// `ask_user` 挂起后落库的真实载荷（`AskUserPendingResponse`）。
    ///
    /// 注意**没有 `kind` 字段**——这正是它与授权载荷的区别。
    private let askUserPayload = #"{"toolCallId":"ask_user","question":"继续构建吗？","options":[],"mode":"yes_no","conversationId":"","verbosity":"standard"}"#

    /// 授权挂起载荷（`ToolInteractionPayload`，`kind == "permission"`）。
    private let permissionPayload = #"{"toolCallId":"approval:call_x","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#

    /// 构造一条 LLM 响应刚落库时的 assistant 消息。
    private func assistantMessage(
        conversationID: UUID,
        assistantMessageID: UUID,
        turnID: UUID,
        toolCallID: String,
        toolName: String,
        arguments: String,
        authorizationState: ToolCallAuthorizationState
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
                    name: toolName,
                    arguments: arguments,
                    displayDescription: "工具调用",
                    authorizationState: authorizationState.rawValue
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

    // MARK: - 用例

    /// `ask_user` 挂起时，授权状态**不得**被改成 `pendingAuthorization`。
    ///
    /// `ask_user` 不需要授权（风险 `.safe`），它需要的是用户的**回答**。
    /// 把它标成待授权，等于告诉渲染层「这里有一次待处理的工具授权」，
    /// 而授权卡片构造不出请求 → 「无法解析工具审批请求」。
    @Test("ask_user 挂起不得被标成待授权")
    func askUserSuspensionKeepsNonAuthorizationState() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_ask_user_1"
        let loop = makeLoop(messages: messages)

        // `ask_user` 在 LLM 响应阶段就被判定为 autoApproved（风险 .safe）。
        messages.insertMessage(
            assistantMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID,
                toolName: "ask_user",
                arguments: #"{"question":"继续构建吗？","mode":"yes_no"}"#,
                authorizationState: .autoApproved
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "ask_user",
                arguments: #"{"question":"继续构建吗？","mode":"yes_no"}"#,
                authorizationState: .autoApproved
            )],
            results: [.executed(ToolCallResult(
                content: askUserPayload,
                isError: false,
                awaitingUserResponse: true,
                interactionState: .waiting
            ))]
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        #expect(
            stored?.authorizationState != ToolCallAuthorizationState.pendingAuthorization.rawValue,
            """
            ask_user 挂起后被标成 pendingAuthorization。ask_user 不需要授权，\
            需要的是回答；标成待授权会让通用授权卡片接管这条工具行，\
            而它构造不出授权请求，界面就出现「无法解析工具审批请求」。\
            实际：\(stored?.authorizationState ?? "nil")
            """
        )
        // 挂起本身必须照常落库，否则界面看不到等待状态。
        #expect(stored?.result?.awaitingUserResponse == true)
    }

    /// 反向对照：真正的授权挂起**必须**回落成 `pendingAuthorization`。
    ///
    /// 这是上一条的镜像：区分挂起类型不得把「授权卡片该出现时却不出现」带进来。
    /// 授权卡片依赖 `pendingAuthorization`，不回落就画不出卡片。
    @Test("授权挂起仍然回落为待授权")
    func permissionSuspensionStillResetsToPending() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_permission_1"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            assistantMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID,
                toolName: "edit_file",
                arguments: #"{"file_path":"/tmp/a.txt"}"#,
                authorizationState: .autoApproved
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "edit_file",
                arguments: #"{"file_path":"/tmp/a.txt"}"#,
                authorizationState: .autoApproved
            )],
            results: [.executed(ToolCallResult(
                content: permissionPayload,
                isError: false,
                awaitingUserResponse: true,
                interactionState: .waiting
            ))]
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        #expect(
            stored?.authorizationState == ToolCallAuthorizationState.pendingAuthorization.rawValue,
            "授权挂起必须回落为 pendingAuthorization，否则授权卡片画不出来"
        )
    }

    /// 判据必须是载荷本身，而不是「工具名」。
    ///
    /// 载荷里的 `kind` 字段是唯一可靠的区分依据——它由载荷生产者自己写，
    /// 不依赖工具注册表、风险等级或调用来源。
    @Test("挂起类型由载荷的 kind 字段决定")
    func suspensionKindIsDecidedByPayload() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_kind_1"
        let loop = makeLoop(messages: messages)

        messages.insertMessage(
            assistantMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID,
                toolName: "some_tool",
                arguments: "{}",
                authorizationState: .autoApproved
            ),
            to: conversationID
        )

        await loop.handleToolManagerEvent(.batchCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCalls: [ToolCall(
                id: toolCallID,
                name: "some_tool",
                arguments: "{}",
                authorizationState: .autoApproved
            )],
            results: [.executed(ToolCallResult(
                content: askUserPayload,
                isError: false,
                awaitingUserResponse: true,
                interactionState: .waiting
            ))]
        ))

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })

        // 载荷没有 kind == "permission"，就不是授权请求。
        #expect(
            stored?.authorizationState != ToolCallAuthorizationState.pendingAuthorization.rawValue,
            "载荷不是授权载荷，却被标成待授权"
        )
    }
}
