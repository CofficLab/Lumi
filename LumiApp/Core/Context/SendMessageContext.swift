import Foundation
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
            currentFileURL: currentFileURL
        )
    }

    // MARK: - Public Methods
    
    /// 便捷方法：终止当前发送并保存一条系统消息到会话中
    ///
    /// 用于中间件在终止发送时同时通知用户原因（如"请求已取消"、"无法连接到服务"等）。
    ///
    /// - Parameter systemMessage: 要保存的系统消息，会显示在聊天界面中
    func abort(withMessage systemMessage: ChatMessage) {
        chatHistoryService.saveMessage(systemMessage, toConversationId: conversationId)
        abortTurn?()
    }
}
