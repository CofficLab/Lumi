import Foundation
import LLMKit
import LumiCoreKit

/// 消息发送上下文
///
/// 在消息发送流程中贯穿整个中间件管道，承载本轮发送所需的全部状态和依赖。
///
/// ## 设计目的
/// - 作为中间件之间的数据载体，避免在中间件间传递过多参数
/// - 提供对本轮发送流程的控制能力（如 abort、临时提示词注入）
/// - 集中管理 LLM 请求所需的配置、项目上下文和历史记录服务
///
/// ## 生命周期
/// 每次用户发送消息时创建一个新实例，随本轮发送完成而销毁。
/// 中间件可修改其可变属性（如 `transientSystemPrompts`、`abortTurn`），
/// 这些修改仅在当前发送轮次内有效，不会持久化。
@MainActor
final class SendMessageContext: LumiCoreKit.SendMessageContext {

    // MARK: - Runtime Dependencies

    /// 聊天记录服务，用于读取/保存会话消息
    let chatHistoryService: ChatHistoryService
    
    /// LLM 代理会话配置（模型选择、参数设置等）
    let agentSessionConfig: AppLLMVM
    
    /// 当前项目视图模型，提供项目路径、语言等信息
    let projectVM: WindowProjectVM
    
    /// 最近项目列表视图模型，用于项目上下文注入
    let recentProjectsVM: AppProjectsVM
    
    // MARK: - Initializer
    
    init(
        conversationId: UUID,
        message: ChatMessage,
        chatHistoryService: ChatHistoryService,
        agentSessionConfig: AppLLMVM,
        projectVM: WindowProjectVM,
        recentProjectsVM: AppProjectsVM,
        currentFileURL: URL?
    ) {
        self.chatHistoryService = chatHistoryService
        self.agentSessionConfig = agentSessionConfig
        self.projectVM = projectVM
        self.recentProjectsVM = recentProjectsVM
        super.init(
            conversationId: conversationId,
            message: message,
            currentFileURL: currentFileURL,
            currentProjectPath: projectVM.currentProjectPath,
            languagePreference: projectVM.languagePreference,
            previousMessages: chatHistoryService.loadMessages(forConversationId: conversationId) ?? [],
            conversationTitleProvider: { [chatHistoryService] conversationId in
                chatHistoryService.fetchConversation(id: conversationId)?.title
            },
            conversationTitleGenerator: { [chatHistoryService, agentSessionConfig] userMessage in
                let config: LLMConfig
                if let conversation = chatHistoryService.fetchConversation(id: conversationId),
                   let providerId = conversation.providerId,
                   let model = conversation.model,
                   let conversationConfig = agentSessionConfig.makeConfig(providerId: providerId, model: model) {
                    config = conversationConfig
                } else {
                    config = agentSessionConfig.getCurrentConfig()
                }
                return await chatHistoryService.generateConversationTitle(from: userMessage, config: config)
            },
            conversationTitleUpdater: { [chatHistoryService] conversationId, title in
                guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else { return false }
                chatHistoryService.updateConversationTitle(conversation, newTitle: title)
                return true
            }
        )
        self.abortWithMessage = { [chatHistoryService, conversationId] message in
            chatHistoryService.saveMessage(message, toConversationId: conversationId)
        }
    }

}
