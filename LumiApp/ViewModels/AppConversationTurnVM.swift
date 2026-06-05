import Foundation
import SwiftUI
import AgentToolKit
import LumiCoreKit

/// 供 UI 侧读取的最小服务集合：当前只保留 prompt/tool 能力。
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var conversationTurnServices: AppConversationTurnVM` 访问。
@MainActor
final class AppConversationTurnVM: ObservableObject {
    let promptService: PromptService
    let toolService: ToolService
    private weak var rootContainer: RootContainer?

    init(promptService: PromptService, toolService: ToolService) {
        self.promptService = promptService
        self.toolService = toolService
    }

    /// 保留对 RootContainer 的弱引用（在 configurePluginRuntimeContext 调用后设置）
    func setRootContainer(_ container: RootContainer) {
        self.rootContainer = container
    }

    // MARK: - Resume Awaiting Tool Call

    /// 恢复等待用户回答的工具调用。
    ///
    /// 当 `ask_user` 等工具暂停了 Agent 循环后，用户在 UI 上做出选择，
    /// 渲染器通过 `AskUserBridge` → `PluginRuntimeContext.resumeToolCall` 调用此方法。
    ///
    /// 步骤：
    /// 1. 加载消息历史，找到包含 pending toolCall 的 assistant 消息
    /// 2. 将 toolCall.result 从 `awaitingUserResponse` 更新为用户真实答案
    /// 3. 保存消息
    /// 4. 将 isProcessing 重新设为 true，触发 AgentTurnService.run() 继续
    func resumeAwaitingToolCall(
        conversationId: UUID,
        toolCallId: String,
        answer: String,
        conversationVM: WindowConversationVM,
        messageQueueVM: WindowMessageQueueVM
    ) {
        guard let container = rootContainer else { return }

        // 1. 加载消息，找到 pending 的 assistant 消息
        let messages = container.chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
        guard let assistantIndex = messages.lastIndex(where: { $0.role == .assistant }),
              var toolCalls = messages[assistantIndex].toolCalls else { return }

        // 2. 找到目标 toolCall 并更新 result
        guard let callIndex = toolCalls.firstIndex(where: { $0.id == toolCallId }) else { return }
        toolCalls[callIndex].result = ToolCallResult(
            content: "用户回答: \(answer)",
            isError: false
        )

        // 3. 保存更新后的 assistant 消息
        var updatedMessage = messages[assistantIndex]
        updatedMessage.toolCalls = toolCalls
        conversationVM.saveMessage(updatedMessage, to: conversationId)

        // 4. 触发 AgentTurnService.run() 继续
        //    isProcessing 标记在暂停时未被清除，仍然为 true，无需重新设置。
        let sendController = container.windowManagerVM.activeWindowContainer?.sendController
        Task {
            await sendController?.resumeAfterAwaitingUserResponse(conversationId: conversationId)
        }
    }
}

