import Foundation
import MagicKit
import OSLog

/// 会话标题生成任务
///
/// 负责在后台为新对话生成描述性标题
/// 当用户发送第一条消息时触发，自动生成简洁的对话标题
struct ConversationTitleGenerationJob: SuperLog {
    nonisolated static let emoji = "🏷️"
    nonisolated static let verbose = true
}

// MARK: - 任务执行

extension ConversationTitleGenerationJob {
    /// 执行会话标题生成任务
    ///
    /// - Parameters:
    ///   - conversationId: 对话 ID
    ///   - messageId: 触发标题生成的消息 ID
    ///   - userMessageContent: 用户消息内容
    ///   - config: LLM 配置
    func run(
        conversationId: UUID,
        messageId: UUID,
        userMessageContent: String,
        config: LLMConfig
    ) async {
        // 聊天历史服务实例
        let chatHistoryService = ChatHistoryService.shared
        
        // 检查是否满足生成标题的条件
        let trimmedMessage = userMessageContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 消息内容为空，跳过")
            }
            return
        }

        if Self.verbose {
            os_log("\(Self.t)🎯 开始为对话 \(conversationId) 生成标题...")
        }

        // 获取对话信息
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 对话 \(conversationId) 不存在")
            }
            return
        }
        
        // 检查标题是否还是默认的 "新会话 "
        guard conversation.title.hasPrefix("新会话 ") else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 对话已有自定义标题，跳过")
            }
            return
        }

        // 使用 ChatHistoryService 生成标题（内部会调用 LLM）
        let title = await chatHistoryService.generateConversationTitle(
            from: trimmedMessage,
            config: config
        )

        // 再次检查并更新对话标题
        guard let freshConversation = chatHistoryService.fetchConversation(id: conversationId),
              freshConversation.title.hasPrefix("新会话 ") else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 对话标题已被修改，放弃更新")
            }
            return
        }
        
        chatHistoryService.updateConversationTitle(freshConversation, newTitle: title)
        
        if Self.verbose {
            os_log("\(Self.t)✅ 对话标题已生成：\(title)")
        }
    }
}
