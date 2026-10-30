import Foundation
import KitAgentTool
import ProviderMessage
import ProviderMessageRendering
import Testing
@testable import PluginMessageRenderer

/// 复现：**挂起的 `ask_user` 交互被通用授权卡片接管，渲染出「无法解析工具审批请求」。**
///
/// ## 症状
///
/// 用户反馈：界面上偶尔出现「无法解析工具审批请求」这句话，但**整个流程
/// 看起来一切正常**——回合继续推进、提问卡片照常出现在底部、回答也能提交。
///
/// ## 根因
///
/// 通用授权卡片渲染器 `ToolApprovalRowRenderer.canRender` 的判据只有两条：
///
/// ```
/// authorizationState == .pendingAuthorization
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// 这两条**无法区分「等授权」与「等回答」**。而提交 `9bc46bfea`
/// （fix(agent-loop): render the authorization card for tools that suspend in
/// A3 chats）之后，`AgentLoopManager` 在持久化**任何**挂起结果时都会把
/// 授权状态回落成 `pendingAuthorization`：
///
/// ```swift
/// authorizationState: result.awaitingUserResponse
///     ? ToolCallAuthorizationState.pendingAuthorization.rawValue
///     : nil
/// ```
///
/// 该回落逻辑写在 `AgentLoopProvider+Tool.swift` 的三个位置（Tool Job 终态
/// 路径、批次 `.executed` 分支、批次 `.needsUserResponse` 分支），**不区分
/// 挂起原因**。于是 `ask_user`（提问工具，风险 `.safe`）挂起时同样落成
/// `pendingAuthorization` + `awaitingUserResponse = true`，被通用授权卡片抢走。
///
/// 但 `ask_user` 的载荷根本不是授权载荷：`AskUserPendingResponse` 的字段是
/// `toolCallId / question / options / mode / conversationId / verbosity`，
/// **没有 `kind` 字段**，因此：
///
/// - `ToolApprovalBridge.permissionRequest` 的第一条路（解 `kind == "permission"`）
///   失败；
/// - 第二条路（按 `riskLevel` 兜底构造）也失败——`ask_user` 的
///   `permissionRiskLevel` 恒为 `.safe`，`requiresPermission == false`。
///
/// 于是 `permissionRequest` 返回 nil，`ToolApprovalRowRenderer.render` 落到
/// 兜底分支，渲染出「无法解析工具审批请求」。
///
/// ## 为什么「一切看起来正常」
///
/// `ask_user` 的交互界面由**底部 ChatSection 固定项**（`AskUserChatSection`）
/// 展示，与消息正文里的工具行是两条独立通路。因此消息正文里那行工具渲染成
/// 一句错误提示，并不会阻断提问卡片的出现、也不会阻断回合的恢复——用户看到
/// 的就是「有一行怪文字，但一切照常」。
///
/// 这一层锁住什么
///
/// 本文件锁住**渲染层的误接管判据**：挂起且带 `pendingAuthorization` 并不等于
/// 「这是一次工具授权请求」。载荷才是可靠证据——Computer Use 的授权渲染器
/// 正是这么改的（`ComputerUseAuthorizationRowRenderer` 不再依赖
/// `pendingAuthorization`）。
@MainActor
@Suite("挂起的交互不得被通用授权卡片误接管")
struct ToolApprovalMisclaimTests {

    // MARK: - 夹具

    /// `ask_user` 挂起后落库的真实形态。
    ///
    /// 载荷字段与 `AskUserPendingResponse` 完全一致（注意**没有 `kind`**），
    /// 授权状态是 `9bc46bfea` 回落后的 `pendingAuthorization`。
    private func askUserSuspendedToolCall(id: String) -> MessageToolCall {
        let payload = #"{"toolCallId":"ask_user","question":"继续构建吗？","options":[],"mode":"yes_no","conversationId":"","verbosity":"standard"}"#
        return MessageToolCall(
            id: id,
            name: "ask_user",
            arguments: #"{"question":"继续构建吗？","mode":"yes_no"}"#,
            result: MessageToolResult(
                content: payload,
                awaitingUserResponse: true,
                interactionState: .waiting
            ),
            displayDescription: "向用户提问：继续构建吗？",
            authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
        )
    }

    /// 真正的工具授权请求落库形态（对照）。
    private func realPermissionToolCall(id: String) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: "edit_file",
            arguments: #"{"file_path":"/tmp/a.txt","old_string":"a","new_string":"b"}"#,
            result: MessageToolResult(
                content: #"{"toolCallId":"approval:\#(id)","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                awaitingUserResponse: true,
                interactionState: .waiting
            ),
            displayDescription: "编辑 a.txt",
            authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
        )
    }

    // MARK: - 用例

    /// 挂起的 `ask_user` 不得被通用授权卡片接管。
    ///
    /// 这是用户报告的那句「无法解析工具审批请求」的直接来源：
    /// 渲染器命中了这条工具行，却构造不出授权请求。
    @Test("挂起的 ask_user 不被通用授权卡片接管")
    func askUserSuspensionIsNotClaimedByApprovalRenderer() {
        let renderer = ToolApprovalRowRenderer()
        let toolCall = askUserSuspendedToolCall(id: "call-ask-user-pending").agentToolCall

        #expect(
            !renderer.canRender(toolCall: toolCall),
            """
            挂起的 ask_user 被通用授权卡片接管了。该载荷不是授权载荷\
            （没有 kind 字段），构造不出授权请求，渲染结果就是\
            「无法解析工具审批请求」。
            """
        )
    }

    /// 反向证明：接管发生的那一刻，授权请求必然构造不出来。
    ///
    /// 这条用例把「误接管」与「构造不出请求」两件事绑在一起，证明症状与根因
    /// 的对应关系：只要误接管成立，`render` 就会落到错误文案分支。
    @Test("被误接管时授权请求必然构造不出来")
    func misclaimedToolCallCannotBuildRequest() {
        let toolCall = askUserSuspendedToolCall(id: "call-ask-user-no-request").agentToolCall

        #expect(
            ToolApprovalBridge.shared.permissionRequest(for: toolCall) == nil,
            "ask_user 载荷构造出了授权请求，说明误接管的成因另有其他"
        )
    }

    /// 真正的工具授权请求**必须**仍然被接管。
    ///
    /// 这是上一条的镜像：修复误接管不得把「授权卡片该出现时却不出现」一起带进来。
    @Test("真正的工具授权请求仍然被接管")
    func realPermissionRequestIsStillClaimed() {
        let renderer = ToolApprovalRowRenderer()
        let toolCall = realPermissionToolCall(id: "call-real-permission").agentToolCall

        #expect(
            renderer.canRender(toolCall: toolCall),
            "真正的工具授权请求没有被接管，授权卡片不会显示"
        )
        #expect(
            ToolApprovalBridge.shared.permissionRequest(for: toolCall) != nil,
            "真正的工具授权请求构造失败，授权卡片会退化成错误文案"
        )
    }

    /// 载荷判据必须是唯一依据：挂起 + `pendingAuthorization` 不足以证明是授权。
    ///
    /// 这条用例直接断言「两条弱信号不能推出授权请求」，是本文件的核心主张。
    @Test("挂起加 pendingAuthorization 不足以判定为授权请求")
    func suspensionAloneDoesNotImplyAuthorization() {
        let toolCall = askUserSuspendedToolCall(id: "call-signal-only").agentToolCall

        // 两条弱信号都成立。
        #expect(toolCall.authorizationState == .pendingAuthorization)
        #expect(toolCall.result?.awaitingUserResponse == true)
        // 但它们推不出「这是一次授权请求」。
        #expect(
            ToolApprovalBridge.shared.permissionRequest(for: toolCall) == nil,
            "仅凭挂起状态就构造出了授权请求，误接管的根因未解决"
        )
    }
}
