import Foundation
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// 一次工具/交互导致的回合暂停点。
///
/// `kind` 是由交互提供方定义的不透明分类，`payload` 是交互提供方的 JSON
/// 字符串（选项、问题等）。用户回答后经 `resumeTurn(in:request:)` 恢复。
public struct AgentLoopSuspension: Sendable, Equatable {
    public let suspensionID: String
    public let conversationID: UUID
    public let toolCallID: String?
    public let kind: String
    public let payload: String

    public init(
        suspensionID: String,
        conversationID: UUID,
        toolCallID: String? = nil,
        kind: String,
        payload: String
    ) {
        self.suspensionID = suspensionID
        self.conversationID = conversationID
        self.toolCallID = toolCallID
        self.kind = kind
        self.payload = payload
    }

    /// 该挂起点是否是 `ask_user` 提问。
    ///
    /// `ask_user` 与工具授权都是「等用户输入」，但语义相反：
    ///
    /// - **工具授权**（`kind == "permission"`，`toolCallId == "approval:<id>"`）
    ///   是系统的安全闸门，用户的新消息**不能**替代授权决定——必须继续排队。
    /// - **`ask_user`** 只是模型向用户提问。用户完全可以用继续聊天来跳过它，
    ///   新消息应当直接落库，由 `MessageObserver` 以「跳过」答案恢复原回合。
    ///
    /// 判别口径与 `PluginGoalTask` 的 `GoalTaskTurnFinishedHook` 保持一致：
    /// `suspensionID` 前缀为 `userInput:`、payload JSON 的 `toolCallId` 为
    /// `"ask_user"`、且 `question` 非空。
    ///
    /// - Note: 参数校验失败的 `ask_user` 同样会进入 `awaitingUserResponse`，
    ///   但其结果以错误前缀开头，不构成一个真正的提问，因此要求
    ///   `question` 非空才认定为提问。
    public var isAskUserSuspension: Bool {
        guard suspensionID.hasPrefix("userInput:") else { return false }
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["toolCallId"] as? String == "ask_user" else {
            return false
        }
        return (object["question"] as? String)?.isEmpty == false
    }

    /// 该挂起点是否在等待用户做**授权**决定。
    ///
    /// 与 `isAskUserSuspension` 互斥：授权挂起（通用工具授权
    /// `kind == "permission"`、Computer Use 应用授权
    /// `kind == "computer_use_authorization"`）等的是「允许 / 拒绝」，
    /// 而 `ask_user` 等的是用户的回答。
    ///
    /// 会话级授权状态只应在这类挂起期间标记为 `.required`，
    /// 否则会话列表会把普通提问误显示成授权盾牌。
    ///
    /// - Note: 判据来自共享契约 `ToolSuspensionKind`，不在此处硬编码
    ///   载荷字段，避免生产者与消费者各自漂移。
    public var isAuthorizationSuspension: Bool {
        ToolSuspensionKind.isAuthorizationRequest(payload)
    }
}
