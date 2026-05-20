import Foundation
import MagicKit

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
final class SendMessageContext {
    
    // MARK: - Immutable Properties
    
    /// 所属会话的唯一标识
    let conversationId: UUID
    
    /// 用户本次发送的聊天消息
    let message: ChatMessage
    
    /// 聊天记录服务，用于读取/保存会话消息
    let chatHistoryService: ChatHistoryService
    
    /// LLM 代理会话配置（模型选择、参数设置等）
    let agentSessionConfig: AppLLMVM
    
    /// 当前项目视图模型，提供项目路径、语言等信息
    let projectVM: WindowProjectVM
    
    /// 最近项目列表视图模型，用于项目上下文注入
    let recentProjectsVM: AppProjectsVM
    
    /// 当前选中的文件 URL（可选）
    /// 当用户在特定文件中触发发送时使用，用于注入文件上下文
    let currentFileURL: URL?
    
    // MARK: - Mutable Properties
    
    /// 仅在当前发送轮次有效的 system 提示词（不落库）
    ///
    /// 中间件可以将临时提示词添加到此数组，供 LLM 请求时使用。
    /// 这些提示词不会被保存到历史记录中，仅参与本次请求。
    ///
    /// **使用场景**：
    /// - 文件内容注入中间件：将打开的文件内容作为提示词
    /// - 项目上下文中间件：注入项目结构信息
    /// - 工具调用中间件：注入工具使用指南
    var transientSystemPrompts: [String] = []

    /// 终止本轮发送的回调
    ///
    /// 中间件可以调用此回调来立即终止本轮发送流程。
    /// 调用后，后续的中间件和 LLM 请求都不会执行。
    ///
    /// **使用场景**：
    /// - 检测到重复消息时跳过发送
    /// - 用户主动取消发送
    /// - 前置校验失败（如网络不可用、API 限额等）
    var abortTurn: (() -> Void)?

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
        self.conversationId = conversationId
        self.message = message
        self.chatHistoryService = chatHistoryService
        self.agentSessionConfig = agentSessionConfig
        self.projectVM = projectVM
        self.recentProjectsVM = recentProjectsVM
        self.currentFileURL = currentFileURL
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
