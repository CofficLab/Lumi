import Foundation
import AgentToolKit
import LLMKit
import SwiftData
import SwiftUI

///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有，通过 `.environmentObject()` 注入。nView 通过 `@EnvironmentObject var conversationVM: WindowConversationVM` 访问。
/// 会话管理 ViewModel
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var conversationVM: WindowConversationVM` 访问。
@MainActor
final class WindowConversationVM: ObservableObject, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "💬"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true
    
    // MARK: - 服务依赖

    /// 聊天历史服务
    ///
    /// 负责会话和消息的持久化操作。
    private let chatHistoryService: ChatHistoryService

    /// 提示词服务
    ///
    /// 用于生成欢迎消息。
    private let promptService: PromptService

    /// Agent 会话配置
    ///
    /// 用于获取当前聊天模式。
    private let agentSessionConfig: AppLLMVM

    // MARK: - 会话状态

    /// 选中的会话 ID
    ///
    /// 此类只维护此 ID，不持有 Conversation 对象引用。
    /// 需要会话数据的视图应使用 @Query 根据 ID 自行查询：
    ///
    /// ```swift
    /// @Query(filter: #Predicate<Conversation> { $0.id == viewModel.selectedConversationId })
    /// var selectedConversation: [Conversation]
    /// ```
    @Published public fileprivate(set) var selectedConversationId: UUID?

    // MARK: - 初始化

    /// 使用依赖服务初始化
    ///
    /// - Parameters:
    ///   - chatHistoryService: 聊天历史服务
    ///   - promptService: 提示词服务
    ///   - agentSessionConfig: Agent 会话配置
    init(
        chatHistoryService: ChatHistoryService,
        promptService: PromptService,
        agentSessionConfig: AppLLMVM
    ) {
        self.chatHistoryService = chatHistoryService
        self.promptService = promptService
        self.agentSessionConfig = agentSessionConfig
    }

    // MARK: - 会话管理

    /// 保存消息到当前对话
    ///
    /// - Parameter message: 要保存的消息
    func saveMessage(_ message: ChatMessage) async {
        guard let conversationId = selectedConversationId else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 当前没有选中会话，跳过保存")
            }
            return
        }
        saveMessage(message, to: conversationId)
    }

    /// 保存消息到指定对话
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversationId: 目标对话 ID
    func saveMessage(_ message: ChatMessage, to conversationId: UUID) {
        chatHistoryService.saveMessage(message, toConversationId: conversationId)
    }

    // MARK: - 对话模型偏好

    /// 保存当前对话的供应商/模型偏好
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    func saveModelPreference(providerId: String, model: String) {
        guard let conversationId = selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 没有选中会话，跳过保存模型偏好")
            }
            return
        }
        chatHistoryService.updateModelPreference(conversation, providerId: providerId, model: model)
        objectWillChange.send()
    }

    /// 保存指定对话的供应商/模型偏好。
    func saveModelPreference(for conversationId: UUID, providerId: String, model: String) {
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 找不到会话，跳过保存模型偏好")
            }
            return
        }
        chatHistoryService.updateModelPreference(conversation, providerId: providerId, model: model)
        if conversationId == selectedConversationId {
            objectWillChange.send()
        }
    }

    /// 获取当前对话的供应商/模型偏好
    /// - Returns: 包含供应商和模型的元组，如果对话未指定则返回 nil
    func getModelPreference() -> (providerId: String, model: String)? {
        guard let conversationId = selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            return nil
        }
        guard let providerId = conversation.providerId,
              let model = conversation.model else {
            return nil
        }
        return (providerId, model)
    }

    /// 获取指定对话的供应商/模型偏好。
    func getModelPreference(for conversationId: UUID) -> (providerId: String, model: String)? {
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId),
              let providerId = conversation.providerId,
              let model = conversation.model else {
            return nil
        }
        return (providerId, model)
    }

    /// 根据对话级模型偏好解析请求配置；未配置或配置失效时回退到应用默认配置。
    func resolveModelConfig(for conversationId: UUID, fallbackConfigProvider: AppLLMVM) -> LLMConfig {
        if let preference = getModelPreference(for: conversationId),
           let config = fallbackConfigProvider.makeConfig(
               providerId: preference.providerId,
               model: preference.model
           ) {
            return config
        }
        return fallbackConfigProvider.getCurrentConfig()
    }

    /// 保存当前对话的聊天模式偏好
    /// - Parameter chatMode: 聊天模式，传入 nil 表示清除对话级偏好
    func saveChatModePreference(_ chatMode: ChatMode?) {
        guard let conversationId = selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 没有选中会话，跳过保存聊天模式")
            }
            return
        }
        chatHistoryService.updateChatMode(conversation, chatMode: chatMode?.rawValue)
    }

    /// 获取当前对话的聊天模式偏好
    /// - Returns: 聊天模式，如果对话未指定则返回 nil
    func getChatModePreference() -> ChatMode? {
        guard let conversationId = selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId),
              let rawValue = conversation.chatMode else {
            return nil
        }
        return ChatMode(rawValue: rawValue)
    }

    /// 保存当前对话的响应详细程度偏好
    /// - Parameter verbosity: 详细程度，传入 nil 表示清除对话级偏好
    func saveVerbosityPreference(_ verbosity: ResponseVerbosity?) {
        guard let conversationId = selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 没有选中会话，跳过保存详细程度")
            }
            return
        }
        chatHistoryService.updateVerbosity(conversation, verbosity: verbosity?.rawValue)
    }

    /// 获取当前对话的响应详细程度偏好
    /// - Returns: 详细程度，如果对话未指定则返回 nil
    func getVerbosityPreference() -> ResponseVerbosity? {
        guard let conversationId = selectedConversationId,
              let conversation = chatHistoryService.fetchConversation(id: conversationId),
              let rawValue = conversation.verbosity else {
            return nil
        }
        return ResponseVerbosity(rawValue: rawValue)
    }

    /// 删除指定对话
    /// - Parameter conversation: 要删除的对话
    /// - Note: 调用方（如 AgentRuntime）需要负责清理相关的消息发送队列
    func deleteConversation(_ conversation: Conversation) {
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")
        }

        // 如果删除的是选中的对话，清理状态
        if selectedConversationId == conversation.id {
            selectedConversationId = nil
        }

        chatHistoryService.deleteConversation(conversation)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 对话已删除：\(conversation.title)")
        }
    }

    /// 更新对话标题
    ///
    /// - Parameters:
    ///   - conversation: 要更新的对话
    ///   - newTitle: 新标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
        }
    }

    /// 基于第一条消息生成会话标题
    ///
    /// 使用 LLM 根据用户的第一条消息自动生成会话标题。
    ///
    /// - Parameters:
    ///   - userMessage: 用户的第一条消息
    ///   - config: LLM 配置
    /// - Returns: 生成的标题
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await chatHistoryService.generateConversationTitle(from: userMessage, config: config)
    }

    // MARK: - 会话选择

    /// 设置当前选中的会话
    /// - Parameters:
    ///   - id: 会话 ID，传入 nil 表示清除选择
    ///   - reason: 触发本次选择变更的原因（用于日志追踪）
    func setSelectedConversation(_ id: UUID?, reason: String) {
        // 避免重复设置相同的 ID
        guard selectedConversationId != id else {
            if Self.verbose {
                let idLabel = id?.uuidString ?? "nil"
                AppLogger.core.info("\(Self.t)⚠️ 会话已选中，跳过重复设置: \(idLabel), reason: \(reason)")
            }
            return
        }

        selectedConversationId = id
        let idLabel = id?.uuidString ?? "nil"
        AppLogger.core.info("\(Self.t)选中会话: \(idLabel), reason: \(reason)")
    }

    // MARK: - 获取会话列表

    /// 获取所有对话
    ///
    /// - Returns: 按时间倒序排列的会话列表
    func fetchAllConversations() -> [Conversation] {
        chatHistoryService.fetchAllConversations()
    }

    /// 分页获取对话
    /// - Parameters:
    ///   - limit: 每页数量
    ///   - offset: 偏移量
    /// - Returns: 当前页数据
    func fetchConversationsPage(limit: Int, offset: Int) -> [Conversation] {
        chatHistoryService.fetchConversationsPage(limit: limit, offset: offset)
    }

    /// 根据 ID 获取会话
    /// - Parameter id: 会话 ID
    /// - Returns: 会话，不存在时返回 nil
    func fetchConversation(id: UUID) -> Conversation? {
        chatHistoryService.fetchConversation(id: id)
    }

    // MARK: - 项目-对话联动

    /// 切换到指定项目最近使用的对话
    /// - Parameter projectId: 项目路径
    /// - Returns: 是否成功找到并切换到关联对话
    @discardableResult
    func switchToLatestConversation(forProject projectId: String) -> Bool {
        guard let conversation = chatHistoryService.fetchLatestConversation(projectId: projectId) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📁 项目 [\(projectId)] 无关联对话")
            }
            return false
        }

        setSelectedConversation(conversation.id, reason: "switchToLatestForProject")

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📁 已切换到项目 [\(projectId)] 的最近对话：\(conversation.title)")
        }

        return true
    }

    // MARK: - 会话创建

    /// 创建新会话
    ///
    /// 执行创建新会话的完整流程：创建会话记录、选中、注入欢迎消息。
    /// 如果当前项目存在历史对话且带有模型偏好，新会话将自动继承该偏好。
    ///
    /// - Parameters:
    ///   - projectName: 当前项目名称，为 nil 表示未选择项目
    ///   - projectPath: 当前项目路径，为 nil 表示未选择项目
    ///   - languagePreference: 语言偏好
    func createNewConversation(
        projectName: String? = nil,
        projectPath: String? = nil,
        languagePreference: LanguagePreference = .chinese
    ) async {
        let conversation = chatHistoryService.createConversation(
            projectId: projectPath,
            chatMode: agentSessionConfig.chatMode.rawValue
        )

        // 继承同项目上一条对话的模型偏好
        if let projectPath,
           let latestConversation = chatHistoryService.fetchLatestConversation(projectId: projectPath),
           latestConversation.id != conversation.id,
           let providerId = latestConversation.providerId,
           let model = latestConversation.model {
            chatHistoryService.updateModelPreference(conversation, providerId: providerId, model: model)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📋 新会话继承项目模型偏好：\(providerId) - \(model)")
            }
        }

        setSelectedConversation(conversation.id, reason: "createNewConversation")
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)

        let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !welcomeMessage.isEmpty {
            saveMessage(
                ChatMessage(role: .assistant, conversationId: conversation.id, content: welcomeMessage),
                to: conversation.id
            )
        }
    }
}
