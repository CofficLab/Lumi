import Foundation
import KernelCore
import KitAgentTool
import LumiLoggingKit
import ProviderAgentLoop
import ProviderConversation
import ProviderToolManager
import os

@MainActor
final class ToolApprovalBridge: SuperLog {
    static let shared = ToolApprovalBridge()
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-renderer",
        category: "ToolApprovalBridge"
    )
    nonisolated static let verbose = false

    private weak var agentLoop: (any AgentLoopProviding)?
    private weak var toolManager: (any ToolManagerProviding)?
    private weak var conversations: (any ConversationManaging)?

    private init() {}

    func start(kernel: KernelCoreContainer) {
        agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
        toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        conversations = kernel.resolveProvider((any ConversationManaging).self)
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)授权桥接已启动 agentLoop=\(self.agentLoop != nil, privacy: .public) toolManager=\(self.toolManager != nil, privacy: .public) conversations=\(self.conversations != nil, privacy: .public)"
            )
        }
    }

    func stop() {
        agentLoop = nil
        toolManager = nil
        conversations = nil
        if Self.verbose {
            Self.logger.info("\(Self.t)授权桥接已停止")
        }
    }

    func permissionRequest(for toolCall: ToolCall) -> ToolPermissionRequest? {
        if let content = toolCall.result?.content,
           let request = ToolPermissionRequest.decode(from: content) {
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)使用工具结果中的授权请求 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
                )
            }
            return request
        }
        guard let risk = toolManager?.riskLevel(for: toolCall) else {
            Self.logger.warning(
                "\(Self.t)无法判断工具风险，跳过授权界面 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return nil
        }
        guard risk.requiresPermission else {
            return nil
        }
        
        return ToolPermissionRequest(
            toolCallID: "approval:\(toolCall.id)",
            kind: ToolSuspensionKind.permission,
            question: "此操作被判定为\(risk.displayName)，是否允许执行？\n\(toolManager?.displayDescription(for: toolCall) ?? toolCall.name)",
            options: ["允许", "拒绝"],
            mode: "yes_no"
        )
    }

    func resolve(conversationID: UUID, toolCall: ToolCall, answer: String) {
        Task { @MainActor in
            await performResolve(
                conversationID: conversationID,
                toolCall: toolCall,
                answer: answer
            )
        }
    }

    /// 实际提交授权决定。
    ///
    /// 拆出 async 版本，让边界校验可以被测试同步驱动；按钮侧仍通过
    /// `resolve` 派发到主线程。
    func performResolve(
        conversationID: UUID,
        toolCall: ToolCall,
        answer: String
    ) async {
        guard let toolManager else {
            Self.logger.error(
                "\(Self.t)提交授权结果失败：ToolManager 不可用 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return
        }
        // 卡片可能是回合死掉之后才被点中的旧快照。Stop 只改写持久化占位，
        // 不会广播 ToolManager 事件；没有这道边界校验，点击会直接进入
        // `executeAuthorized`，让用户已经终止的高风险工具照样产生副作用（#1028）。
        guard isAuthorizationStillActive(conversationID: conversationID, toolCall: toolCall) else {
            Self.logger.warning(
                "\(Self.t)忽略过期授权：回合已结束或挂起已不匹配 conversation=\(conversationID.uuidString, privacy: .public) tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return
        }
        let turnID = agentLoop?.currentTurnID(for: conversationID)
        let action = ToolApprovalAction(answer: answer)
        if action == .alwaysAllow {
            guard let conversations else {
                Self.logger.error(
                    "\(Self.t)设置 A3 失败：ConversationManager 不可用 conversation=\(conversationID.uuidString, privacy: .public)"
                )
                return
            }
            conversations.setAutomationLevel(.autonomous, for: conversationID)
            Self.logger.info(
                "\(Self.t)当前对话已切换为 A3 conversation=\(conversationID.uuidString, privacy: .public)"
            )
        }
        let approved = action == .allow || action == .alwaysAllow
        Self.logger.info(
            "\(Self.t)提交授权结果 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public) approved=\(approved, privacy: .public)"
        )
        if approved {
            _ = await toolManager.executeAuthorized(
                toolCall,
                conversationID: conversationID,
                turnID: turnID
            )
        } else {
            _ = await toolManager.rejectAuthorized(
                toolCall,
                conversationID: conversationID,
                turnID: turnID
            )
        }
    }

    /// 授权提交时回合与挂起是否仍然有效。
    ///
    /// - `completed` / `failed` / `cancelled`：回合已经结束，拒绝执行。
    /// - `suspended`：只有当前挂起正指向这个工具调用时才允许，避免同会话
    ///   后续回合的旧卡片跨调用执行。
    /// - `idle`：允许。应用重启后运行时尚未重建，授权卡片复活时仍需可用，
    ///   `prepareRuntimeForToolResult` 会按持久化消息重建回合。
    /// - `running`：允许。恢复窗口内 FSM 可能已离开 `awaitingUser`，但工具
    ///   仍属于当前回合。
    /// - 无法解析 AgentLoop（如精简宿主）：保持旧行为，交由既有执行路径处理。
    func isAuthorizationStillActive(conversationID: UUID, toolCall: ToolCall) -> Bool {
        guard let agentLoop else { return true }
        switch agentLoop.state(for: conversationID) {
        case .completed, .failed, .cancelled:
            return false
        case .suspended:
            return agentLoop.suspension(for: conversationID)?.toolCallID == toolCall.id
        case .idle, .running:
            return true
        }
    }

}
