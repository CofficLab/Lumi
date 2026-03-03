import Foundation
import MagicKit
import OSLog
import SwiftUI

// MARK: - 对话管理与历史记录

extension AssistantViewModel {
    /// 生成会话标题（如果是第一条用户消息）
    func generateTitleIfNeeded(userMessage: String) async {
        // 只在以下条件下生成标题：
        // 1. 尚未生成过标题
        // 2. 当前对话是初始标题 "新会话 "
        // 3. 消息内容非空
        guard !hasGeneratedTitle,
              let conversation = currentConversation,
              conversation.title.hasPrefix("新会话 "),
              !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        hasGeneratedTitle = true

        if Self.verbose {
            os_log("\(self.t)🎯 开始为对话生成标题...")
        }

        // 获取当前 LLM 配置
        let config = getCurrentConfig()

        // 生成标题
        let title = await AgentProvider.shared.chatHistoryService.generateConversationTitle(
            from: userMessage,
            config: config
        )

        // 更新对话标题
        AgentProvider.shared.chatHistoryService.updateConversationTitle(conversation, newTitle: title)
        currentConversation?.title = title

        if Self.verbose {
            os_log("\(self.t)✅ 对话标题已生成：\(title)")
        }
    }

    // MARK: - 历史记录管理

    func clearHistory() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected

        Task {
            let fullSystemPrompt = await AgentProvider.shared.promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
        }
    }

    // MARK: - 加载历史对话

    /// 加载指定对话的消息
    func loadConversation(_ conversationId: UUID) async {
        if Self.verbose {
            os_log("\(self.t)📥 [\(conversationId)] 开始加载对话")
        }

        // 从数据库获取对话
        guard let conversation = AgentProvider.shared.chatHistoryService.fetchConversation(id: conversationId) else {
            return
        }

        await MainActor.run {
            // 重置状态
            withAnimation {
                depthWarning = nil
                errorMessage = nil
                isProcessing = false
                currentInput = ""
                pendingAttachments.removeAll()
            }
        }

        // 设置当前对话
        currentConversation = conversation

        // 加载消息
        let loadedMessages = AgentProvider.shared.chatHistoryService.loadMessages(for: conversation)

        if Self.verbose {
            os_log("\(self.t)📥 [\(conversation.id)] 加载到 \(loadedMessages.count) 条消息")
        }

        // 获取系统提示
        let fullSystemPrompt = await AgentProvider.shared.promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: isProjectSelected
        )

        await MainActor.run {
            // 保留系统消息，添加历史消息
            var newMessages: [ChatMessage] = [ChatMessage(role: .system, content: fullSystemPrompt)]
            newMessages.append(contentsOf: loadedMessages.filter { $0.role != .system })

            withAnimation {
                messages = newMessages
            }
        }

        if Self.verbose {
            os_log("\(self.t)✅ [\(conversation.id)] 对话加载完成")
        }
    }
}
