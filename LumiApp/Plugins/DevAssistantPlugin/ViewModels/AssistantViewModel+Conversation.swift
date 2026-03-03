import Foundation
import MagicKit
import OSLog
import SwiftUI

// MARK: - 对话管理与历史记录

extension AssistantViewModel {
    /// 创建新对话
    func createNewConversation() async {
        let projectId = isProjectSelected ? currentProjectPath : nil
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        currentConversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )
        hasGeneratedTitle = false  // 重置标题生成标记
        
        if let conversationId = currentConversation?.id {
            // 只更新 AgentProvider 的内部状态，不触发通知
            AgentProvider.shared.setSelectedConversationIdWithoutNotification(conversationId)
        }
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) {
        guard let conversation = currentConversation else {
            if Self.verbose {
                os_log("\(self.t)⚠️ 当前没有活动对话，跳过保存")
            }
            return
        }
        
        chatHistoryService.saveMessage(message, to: conversation)
    }
    
    /// 生成会话标题（如果是第一条用户消息）
    func generateTitleIfNeeded(userMessage: String) async {
        // 只在以下条件下生成标题：
        // 1. 尚未生成过标题
        // 2. 当前对话是初始标题 "新对话"
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
        let title = await chatHistoryService.generateConversationTitle(
            from: userMessage,
            config: config
        )
        
        // 更新对话标题
        chatHistoryService.updateConversationTitle(conversation, newTitle: title)
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
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            messages = [ChatMessage(role: .system, content: fullSystemPrompt)]
        }
    }

    /// 开启新会话 - 清除历史并显示欢迎消息
    func startNewChat() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected
        let currentProjectName = self.currentProjectName
        let currentProjectPath = self.currentProjectPath

        withAnimation {
            // 清除深度警告和错误
            depthWarning = nil
            errorMessage = nil
            isProcessing = false
            currentInput = ""
            pendingAttachments.removeAll()
        }

        Task { @MainActor in
            // 创建新对话
            await createNewConversation()
            
            // 重新构建系统提示
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            
            // 构建新会话的初始消息
            var newMessages: [ChatMessage] = [ChatMessage(role: .system, content: fullSystemPrompt)]

            // 显示欢迎消息
            if !isProjectSelected {
                // 未选择项目：显示项目选择引导
                let prompt = await promptService.getWelcomeMessage()
                newMessages.append(ChatMessage(role: .assistant, content: prompt))
            } else {
                // 已选择项目：显示欢迎回来消息
                let welcomeMsg = await promptService.getWelcomeBackMessage(
                    projectName: currentProjectName,
                    projectPath: currentProjectPath,
                    language: languagePreference
                )
                let welcomeMessage = ChatMessage(role: .assistant, content: welcomeMsg)
                newMessages.append(welcomeMessage)
                
                // 保存欢迎消息到数据库
                saveMessage(welcomeMessage)
            }

            // 一次性设置所有消息，避免多次刷新
            messages = newMessages
        }
    }

    // MARK: - 加载历史对话

    /// 加载指定对话的消息
    func loadConversation(_ conversation: Conversation) async {
        if Self.verbose {
            os_log("\(self.t)📥 开始加载对话：\(conversation.title)")
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
        let loadedMessages = chatHistoryService.loadMessages(for: conversation)
        
        if Self.verbose {
            os_log("\(self.t)📥 加载到 \(loadedMessages.count) 条消息")
        }
        
        // 获取系统提示
        let fullSystemPrompt = await promptService.buildSystemPrompt(
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
            os_log("\(self.t)✅ 对话加载完成：\(conversation.title)")
        }
    }
}
