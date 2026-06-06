import Foundation
import LumiCoreKit

/// Turn 结束上下文（App 层扩展）
///
/// 在 `LumiCoreKit.TurnFinishedContext` 基础上注入 App 层服务依赖，
/// 让中间件可以通过上下文访问聊天记录、项目配置等能力。
@MainActor
final class AppTurnFinishedContext: TurnFinishedContext {

    /// 聊天记录服务，用于读取/保存会话消息
    let chatHistoryService: ChatHistoryService

    /// 当前项目视图模型
    let projectVM: WindowProjectVM

    /// 对话 VM，用于保存消息到会话
    let conversationVM: WindowConversationVM

    init(
        conversationId: UUID,
        endReason: TurnEndReason,
        turnMessages: [ChatMessage],
        chatHistoryService: ChatHistoryService,
        projectVM: WindowProjectVM,
        conversationVM: WindowConversationVM
    ) {
        self.chatHistoryService = chatHistoryService
        self.projectVM = projectVM
        self.conversationVM = conversationVM
        super.init(
            conversationId: conversationId,
            endReason: endReason,
            turnMessages: turnMessages
        )
    }
}
