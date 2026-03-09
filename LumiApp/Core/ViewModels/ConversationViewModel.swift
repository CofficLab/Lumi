import Foundation
import SwiftData
import MagicKit
import SwiftUI
import OSLog

/// 会话管理 ViewModel
///
/// 负责处理所有会话相关的业务逻辑：
/// - 创建、加载、删除会话
/// - 会话选择和状态管理
///
/// ## 设计说明
///
/// 此类只维护 `selectedConversationId`，不持有 `Conversation` 对象引用。
/// 需要会话数据的视图应使用 `@Query` 根据 ID 自行查询。
///
/// ## 架构模式
///
/// ```
/// ConversationViewModel
/// ├── ChatHistoryService
/// │   └── 持久化操作
/// ├── LLMService
/// │   └── 标题生成
/// └── PromptService
///     └── 欢迎消息
/// ```
@MainActor
final class ConversationViewModel: ObservableObject, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "💬"
    
    /// 是否启用详细日志
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 聊天历史服务
    ///
    /// 负责会话和消息的持久化操作。
    private let chatHistoryService: ChatHistoryService

    /// LLM 服务（用于生成会话标题）
    ///
    /// 当用户发送第一条消息时，使用 AI 生成会话标题。
    private let llmService: LLMService

    /// 提示词服务（用于获取欢迎消息）
    ///
    /// 获取新会话的欢迎消息内容。
    private let promptService: PromptService



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
    ///
    /// ID 变化时会自动持久化到 UserDefaults。
    @Published public fileprivate(set) var selectedConversationId: UUID? {
        didSet {
            if let id = selectedConversationId {
                UserDefaults.standard.set(id.uuidString, forKey: "Conversation_SelectedId")
            } else {
                UserDefaults.standard.removeObject(forKey: "Conversation_SelectedId")
            }
        }
    }

    // MARK: - 初始化

    /// 使用依赖服务初始化
    ///
    /// - Parameters:
    ///   - chatHistoryService: 聊天历史服务
    ///   - llmService: LLM 服务
    ///   - promptService: 提示词服务
    init(
        chatHistoryService: ChatHistoryService,
        llmService: LLMService,
        promptService: PromptService
    ) {
        self.chatHistoryService = chatHistoryService
        self.llmService = llmService
        self.promptService = promptService

        // 恢复上次选择的会话
        restoreSelectedConversation()
    }

    // MARK: - 会话管理

    /// 保存消息到当前对话
    ///
    /// - Parameter message: 要保存的消息
    func saveMessage(_ message: ChatMessage) {
        guard let conversationId = selectedConversationId else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 当前没有选中会话，跳过保存")
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
        Task(priority: .utility) {
            let saved = await chatHistoryService.saveMessageAsync(message, toConversationId: conversationId)
            if Self.verbose, saved != nil {
                os_log("\(Self.t)💾 [\(conversationId)] 消息已保存：\(message.content.max(50))")
            }
        }
    }

    /// 删除指定对话
    /// - Parameter conversation: 要删除的对话
    /// - Note: 调用方（如 AgentProvider）需要负责清理相关的消息发送队列
    func deleteConversation(_ conversation: Conversation) {
        os_log("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")

        // 如果删除的是选中的对话，清理状态
        if selectedConversationId == conversation.id {
            selectedConversationId = nil
        }

        chatHistoryService.deleteConversation(conversation)

        os_log("\(Self.t)✅ 对话已删除：\(conversation.title)")
    }

    /// 更新对话标题
    ///
    /// - Parameters:
    ///   - conversation: 要更新的对话
    ///   - newTitle: 新标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)

        if Self.verbose {
            os_log("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
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
    /// - Parameter id: 会话 ID，传入 nil 表示清除选择
    func setSelectedConversation(_ id: UUID?) {
        // 避免重复设置相同的 ID
        guard selectedConversationId != id else {
            if let existingId = id, Self.verbose {
                os_log("\(Self.t)⚠️ 会话已选中，跳过重复设置: \(existingId)")
            }
            return
        }

        selectedConversationId = id
    }

    /// 恢复上次选择的会话
    ///
    /// 应用启动时从 UserDefaults 恢复上次选中的会话 ID。
    /// 不验证会话是否存在于数据库，由调用方处理验证。
    func restoreSelectedConversation() {
        guard let savedId = UserDefaults.standard.string(forKey: "Conversation_SelectedId"),
              let uuid = UUID(uuidString: savedId) else {
            return
        }

        selectedConversationId = uuid

        if Self.verbose {
            os_log("\(Self.t)✅ [\(uuid)] 已恢复会话选择")
        }
    }

    // MARK: - 获取会话列表

    /// 获取所有对话
    ///
    /// - Returns: 按时间倒序排列的会话列表
    func fetchAllConversations() -> [Conversation] {
        chatHistoryService.fetchAllConversations()
    }

    /// 获取项目相关的对话
    ///
    /// - Parameter projectId: 项目路径
    /// - Returns: 项目相关的对话列表
    func fetchConversations(forProject projectId: String) -> [Conversation] {
        chatHistoryService.fetchConversations(forProject: projectId)
    }
}
