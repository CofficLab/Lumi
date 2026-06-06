import Foundation
import SwiftUI
import AgentToolKit
import LumiCoreKit

/// 供 UI 侧读取的最小服务集合：当前只保留 prompt/tool 能力。
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
    func resumeAwaitingToolCall(
        conversationId: UUID,
        toolCallId: String,
        answer: String,
        conversationVM: WindowConversationVM
    ) {
        guard let container = rootContainer else { return }

        let messages = container.chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
        guard let assistantIndex = messages.lastIndex(where: { $0.role == .assistant }),
              var toolCalls = messages[assistantIndex].toolCalls else { return }

        guard let callIndex = toolCalls.firstIndex(where: { $0.id == toolCallId }) else { return }
        toolCalls[callIndex].result = ToolCallResult(
            content: "用户回答: \(answer)",
            isError: false
        )

        var updatedMessage = messages[assistantIndex]
        updatedMessage.toolCalls = toolCalls
        conversationVM.saveMessage(updatedMessage, to: conversationId)

        container.conversationService.setTurnPhase(.processing, forConversationId: conversationId)
    }
}
