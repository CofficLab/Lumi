import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager
import Testing
@testable import PluginMessageRenderer

/// 复现：**用户已授权/已拒绝，重新打开消息列表时又出现授权界面。**
///
/// ## 症状与判据
///
/// 授权卡片是否渲染完全由 `ToolApprovalRowRenderer.canRender` 决定：
///
/// ```
/// authorizationState == .pendingAuthorization
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// 因此消息里只要还留着「等待授权的占位结果 + pendingAuthorization」，
/// 用户每次打开这个会话都会被重新要求授权。`ToolCall.authorizationState`
/// 缺失时按 `.pendingAuthorization` 解码（`ToolCall.init(from:)`），
/// 所以「字段丢失」和「未授权」在 UI 上完全无法区分。
///
/// ## 这一层锁住什么
///
/// 这是**用户看得见的判据**本身：给定落库后的消息形态，
/// 渲染器要么渲染授权卡片、要么不渲染。
/// 上游为什么没把 `authorizationState` 写成 `userApproved` / `userRejected`，
/// 由 `ToolAuthorizationPersistenceTests`（PluginAgentLoop）复现；
/// 持久化层本身是健康的，由 `MessageManagerToolAuthorizationTests` 复现。
@Suite("工具授权卡片渲染判定")
@MainActor
struct ToolApprovalVisibilityAfterResolutionTests {

    /// 把落库后的 `MessageToolCall` 桥接成渲染层使用的 `ToolCall`。
    private func agentToolCall(
        id: String,
        authorizationState: ToolCallAuthorizationState,
        result: ToolCallResult?
    ) -> ToolCall {
        MessageToolCall(
            id: id,
            name: "write_file",
            arguments: "{}",
            result: result.flatMap(MessageToolResult.init(toolCallResult:)),
            displayDescription: "写入 /tmp/a.txt",
            authorizationState: authorizationState.rawValue
        ).agentToolCall
    }

    /// 授权前的形态：占位结果 + pendingAuthorization。此时**必须**显示授权卡片。
    @Test("等待授权时显示授权卡片")
    func showsApprovalWhilePending() {
        let renderer = ToolApprovalRowRenderer()
        let pending = self.agentToolCall(
            id: "call-pending",
            authorizationState: .pendingAuthorization,
            result: ToolCallResult(
                content: #"{"toolCallId":"approval:call-pending","kind":"permission","question":"是否允许？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                awaitingUserResponse: true,
                interactionState: .waiting
            )
        )
        #expect(renderer.canRender(toolCall: pending))
    }

    /// 用户点了「允许」并已执行完：重新打开会话**不应**再出现授权卡片。
    @Test("用户已允许后重新打开不再显示授权卡片")
    func hidesApprovalAfterUserApproved() {
        let renderer = ToolApprovalRowRenderer()
        let approved = self.agentToolCall(
            id: "call-approved",
            authorizationState: .userApproved,
            result: ToolCallResult(content: "file written")
        )
        #expect(!renderer.canRender(toolCall: approved))
    }

    /// 用户点了「拒绝」：重新打开会话**不应**再出现授权卡片。
    ///
    /// 拒绝没有工具实际执行，因此结果常常与占位结果同时被替换；
    /// 这里同时覆盖「结果已替换」与「结果尚未替换」两种情况。
    @Test("用户已拒绝后重新打开不再显示授权卡片")
    func hidesApprovalAfterUserRejected() {
        let renderer = ToolApprovalRowRenderer()
        let rejected = agentToolCall(
            id: "call-rejected",
            authorizationState: .userRejected,
            result: ToolCallResult(
                content: "Tool execution was rejected by the user.",
                isError: true
            )
        )
        // 结果已替换。
        #expect(!renderer.canRender(toolCall: rejected))
        // 结果尚未替换：仅靠 authorizationState 也足以隐藏卡片。
        let rejectedNoResult = agentToolCall(
            id: "call-rejected-no-result",
            authorizationState: .userRejected,
            result: nil
        )
        #expect(!renderer.canRender(toolCall: rejectedNoResult))
    }

    /// 复现缺陷的**判据端**。
    ///
    /// 当上游因为 guard 失败而根本没写 `authorizationState` 时，
    /// 消息在磁盘上仍是「占位结果 + pendingAuthorization」。
    /// 本用例把这一形态原样交给渲染器，证明它**必然**重新弹出授权界面——
    /// 也就是用户报告的症状。
    ///
    /// 上游丢失路径由 `ToolAuthorizationPersistenceTests` 覆盖；
    /// 这里只声明「渲染层收到这种数据就会显示授权界面」这个事实，
    /// 因此本用例**应当通过**——它是症状的定义，不是失败。
    @Test("授权状态丢失的形态会重新显示授权卡片（症状定义）")
    func stalePendingFormRedisplayApproval() {
        let renderer = ToolApprovalRowRenderer()
        // authorizationState 缺失，按 ToolCall 的解码规则等价于 pendingAuthorization。
        let stale = MessageToolCall(
            id: "call-lost-state",
            name: "write_file",
            arguments: "{}",
            result: MessageToolResult(
                content: #"{"toolCallId":"approval:call-lost-state","kind":"permission","question":"是否允许？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                awaitingUserResponse: true,
                interactionState: .waiting
            ),
            displayDescription: "写入 /tmp/a.txt",
            authorizationState: nil
        ).agentToolCall

        #expect(stale.authorizationState == .pendingAuthorization)
        #expect(renderer.canRender(toolCall: stale))
    }
}
